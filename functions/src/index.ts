import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import { exec } from "child_process";
import { promisify } from "util";

const execPromise = promisify(exec);
admin.initializeApp();
const db = admin.firestore();

// Worker API Configurations
const WORKER_BASE_URL = "https://atheleos-media-worker.atheleos-media.workers.dev";
const ADMIN_SECRET = "atheleos-admin-secret-key-12345"; // Configured as Worker secret

// --- 1. Video Processing HTTPS Trigger ---

const runtimeOpts = {
  timeoutSeconds: 300,
  memory: "2GB" as const,
};

export const processVideoJob = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
  // Debug GET handler to inspect job failures
  if (req.method === "GET" && req.query.debug === "1") {
    res.set("Access-Control-Allow-Origin", "*");
    try {
      const jobsSnap = await db.collection("processing_jobs").orderBy("updatedAt", "desc").limit(5).get();
      const jobs: any[] = [];
      jobsSnap.forEach(doc => {
        jobs.push({ id: doc.id, ...doc.data() });
      });
      res.status(200).send(jobs);
    } catch (e: any) {
      res.status(500).send({ error: e.message });
    }
    return;
  }

  // Simple CORS preflight handling
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.status(204).send("");
    return;
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).send({ error: "Unauthorized" });
    return;
  }
  const token = authHeader.substring(7);

  const { jobId } = req.body;
  if (!jobId) {
    res.status(400).send({ error: "Missing jobId" });
    return;
  }

  try {
    const jobRef = db.collection("processing_jobs").doc(jobId);
    const jobSnap = await jobRef.get();
    if (!jobSnap.exists) {
      res.status(404).send({ error: "Processing job not found" });
      return;
    }

    const jobData = jobSnap.data()!;
    if (jobData.status === "completed" || jobData.status === "running") {
      res.status(200).send({ status: jobData.status });
      return;
    }

    // Set job status to running
    await jobRef.update({
      status: "running",
      "summary.startedAt": admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Execute processing task with retry and error recovery logic
    try {
      await runTranscodingPipeline(jobId, jobData, token);
      console.log(`Video job ${jobId} finished successfully.`);
      res.status(200).send({ status: "completed" });
    } catch (err: any) {
      console.error(`Transcoding pipeline failed for job ${jobId}:`, err);
      await handleJobFailure(jobId, jobData, err.message || "Unknown transcoding error", token);
      res.status(500).send({ error: err.message || "Transcoding failed" });
    }
  } catch (e: any) {
    console.error("processVideoJob Trigger Error:", e);
    res.status(500).send({ error: e.message || "Internal Server Error" });
  }
});

async function runTranscodingPipeline(jobId: string, jobData: any, token: string) {
  const mediaId = jobData.mediaId;
  const tempFilePath = jobData.tempFilePath; // e.g. "temp/med_xxx_temp.mp4"

  const tempDir = os.tmpdir();
  const localInputPath = path.join(tempDir, `${mediaId}_input.mp4`);
  const localOutputPath = path.join(tempDir, `${mediaId}_optimized.mp4`);
  const localThumbPath = path.join(tempDir, `${mediaId}_thumb.jpg`);

  const startTime = Date.now();

  try {
    // 1. Download staged original video from Cloudflare Worker
    const downloadUrl = `${WORKER_BASE_URL}/${tempFilePath}`;
    const downloadRes = await fetch(downloadUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!downloadRes.ok) {
      throw new Error(`Failed to download original from Worker: ${downloadRes.statusText}`);
    }
    const buffer = Buffer.from(await downloadRes.arrayBuffer());
    await fs.promises.writeFile(localInputPath, buffer);

    // 2. Transcode and optimize with FFmpeg (Limit processing duration to 180s)
    // - Enforce H.264 video, AAC audio, 480p resolution, maintain aspect ratio
    // Detect dimensions & orientation using ffprobe
    const { stdout: ffprobeOut } = await execPromise(
      `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,r_frame_rate,bit_rate -of json "${localInputPath}"`,
      { maxBuffer: 10 * 1024 * 1024 }
    );
    const metadata = JSON.parse(ffprobeOut);
    const stream = metadata.streams?.[0] || {};
    const origWidth = parseInt(stream.width, 10) || 0;
    const origHeight = parseInt(stream.height, 10) || 0;
    const duration = parseFloat(stream.duration) || 0;
    const fps = eval(stream.r_frame_rate || "30");
    // const origBitrate = parseInt(stream.bit_rate, 10) || 0;

    const isPortrait = origHeight > origWidth;
    let targetWidth = 854;
    let targetHeight = 480;
    if (isPortrait) {
      targetWidth = 480;
      targetHeight = 854;
    }

    // Downscale only if source is larger than 480p; maintain exact orientation
    const scaleFilter = `scale=w='if(gt(iw,${targetWidth}),${targetWidth},-1)':h='if(gt(ih,${targetHeight}),${targetHeight},-1)':force_original_aspect_ratio=decrease,pad=${targetWidth}:${targetHeight}:(ow-iw)/2:(oh-ih)/2`;

    // Transcode command (H.264 + AAC + scale to 480p limit)
    // Run with 180 seconds timeout
    const cmd = `ffmpeg -y -nostdin -i "${localInputPath}" -vf "${scaleFilter}" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -t 180 "${localOutputPath}"`;
    await execPromise(cmd, { maxBuffer: 50 * 1024 * 1024 });

    // 3. Simple Thumbnail Generation (Extract frame at 1s or 30% of duration)
    const thumbFrameTime = duration > 2 ? 1 : duration * 0.3;
    const thumbCmd = `ffmpeg -y -nostdin -ss ${thumbFrameTime} -i "${localInputPath}" -vframes 1 -q:v 2 "${localThumbPath}"`;
    await execPromise(thumbCmd, { maxBuffer: 50 * 1024 * 1024 });

    // 4. Upload optimized MP4 and Thumbnail back to Cloudflare Worker
    const videoBuffer = await fs.promises.readFile(localOutputPath);
    const thumbBuffer = await fs.promises.readFile(localThumbPath);

    // Upload optimized video
    const videoUploadUrl = `${WORKER_BASE_URL}/media/${mediaId}.mp4`;
    const videoUpRes = await fetch(videoUploadUrl, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${ADMIN_SECRET}`,
        "Content-Type": "video/mp4",
      },
      body: videoBuffer,
    });
    if (!videoUpRes.ok) {
      throw new Error(`Failed to upload optimized video to Worker: ${videoUpRes.statusText}`);
    }

    // Upload optimized thumbnail
    const thumbUploadUrl = `${WORKER_BASE_URL}/media/${mediaId}_thumb.jpg`;
    const thumbUpRes = await fetch(thumbUploadUrl, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${ADMIN_SECRET}`,
        "Content-Type": "image/jpeg",
      },
      body: thumbBuffer,
    });
    if (!thumbUpRes.ok) {
      throw new Error(`Failed to upload optimized thumbnail to Worker: ${thumbUpRes.statusText}`);
    }

    // Delete temp file from Worker / R2
    const deleteTempUrl = `${WORKER_BASE_URL}/${tempFilePath}`;
    await fetch(deleteTempUrl, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${ADMIN_SECRET}` },
    });

    const endTime = Date.now();
    const durationMs = endTime - startTime;

    // 5. Update Firestore Database documents (Commit via transaction)
    const mediaRef = db.collection("media").doc(mediaId);
    const jobRef = db.collection("processing_jobs").doc(jobId);

    await db.runTransaction(async (transaction) => {
      transaction.update(mediaRef, {
        status: "ready",
        urls: {
          original: `${WORKER_BASE_URL}/media/${mediaId}.mp4`,
          thumbnail: `${WORKER_BASE_URL}/media/${mediaId}_thumb.jpg`,
        },
        sizes: {
          original: jobData.limits.maxFileSize,
          optimized: {
            originalVariant: videoBuffer.length,
            thumbnail: thumbBuffer.length,
          },
        },
        videoMetadata: {
          duration,
          width: targetWidth,
          height: targetHeight,
          aspectRatio: targetWidth / targetHeight,
          bitrate: Math.round((videoBuffer.length * 8) / duration),
          fps,
          codec: {
            video: "h264",
            audio: "aac",
          },
          orientation: isPortrait ? "portrait" : "landscape",
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(jobRef, {
        status: "completed",
        "summary.completedAt": admin.firestore.FieldValue.serverTimestamp(),
        "summary.durationMs": durationMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Cleanup local temp files
    await cleanupLocalFiles([localInputPath, localOutputPath, localThumbPath]);
  } catch (err) {
    await cleanupLocalFiles([localInputPath, localOutputPath, localThumbPath]);
    throw err;
  }
}

async function handleJobFailure(jobId: string, jobData: any, errorMsg: string, token: string) {
  const mediaId = jobData.mediaId;
  const currentRetry = jobData.retryCount || 0;

  const jobRef = db.collection("processing_jobs").doc(jobId);
  const mediaRef = db.collection("media").doc(mediaId);

  if (currentRetry < 3) {
    // Retry automatically up to 3 times with exponential backoff
    const nextRetry = currentRetry + 1;
    console.log(`Retrying job ${jobId} (${nextRetry}/3)`);

    await db.runTransaction(async (transaction) => {
      transaction.update(jobRef, {
        status: "waiting_for_retry",
        retryCount: nextRetry,
        "summary.failureReason": errorMsg,
        lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(mediaRef, {
        status: "processing", // keep status processing
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Wait and trigger again
    const videoProcessorUrl = `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/processVideoJob`;
    const delay = Math.pow(2, nextRetry) * 1000;
    setTimeout(() => {
      triggerVideoProcessor(videoProcessorUrl, jobId, token);
    }, delay);
  } else {
    // Exhausted retries: Move to Dead Letter Queue (DLQ)
    console.log(`Job ${jobId} failed completely. Moving to DLQ.`);
    const dlqRef = db.collection("dead_letter_jobs").doc(jobId);

    await db.runTransaction(async (transaction) => {
      transaction.set(dlqRef, {
        jobId,
        mediaId,
        failedJobDetails: {
          ...jobData,
          status: "failed",
          summary: {
            ...jobData.summary,
            failureReason: errorMsg,
            completedAt: admin.firestore.Timestamp.now(),
          },
        },
        movedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(jobRef, {
        status: "failed",
        "summary.failureReason": errorMsg,
        "summary.errorCode": "FAILED_ALL_RETRIES",
        "summary.completedAt": admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(mediaRef, {
        status: "failed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Cleanup temporary storage file from Worker / R2
    const deleteTempUrl = `${WORKER_BASE_URL}/${jobData.tempFilePath}`;
    await fetch(deleteTempUrl, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${ADMIN_SECRET}` },
    });
  }
}

async function cleanupLocalFiles(paths: string[]) {
  for (const p of paths) {
    try {
      if (fs.existsSync(p)) {
        await fs.promises.unlink(p);
      }
    } catch (_) {}
  }
}

// --- 2. Automated Reference Counting Firestore Triggers ---

export const onPostWrite = functions.firestore.document("posts/{postId}").onWrite(async (change, context) => {
  await handleReferenceTrigger(change, "post", context.params.postId);
});

export const onStoryWrite = functions.firestore.document("stories/{storyId}").onWrite(async (change, context) => {
  await handleReferenceTrigger(change, "story", context.params.storyId);
});

export const onEventWrite = functions.firestore.document("events/{eventId}").onWrite(async (change, context) => {
  await handleReferenceTrigger(change, "event", context.params.eventId);
});

export const onProfileWrite = functions.firestore.document("users/{userId}").onWrite(async (change, context) => {
  await handleReferenceTrigger(change, "profile", context.params.userId);
});

async function handleReferenceTrigger(change: functions.Change<admin.firestore.DocumentSnapshot>, sourceType: string, docId: string) {
  const oldData = change.before.exists ? change.before.data() : null;
  const newData = change.after.exists ? change.after.data() : null;

  const oldMediaIds = extractMediaIds(oldData, sourceType);
  const newMediaIds = extractMediaIds(newData, sourceType);

  const added = newMediaIds.filter(id => !oldMediaIds.includes(id));
  const removed = oldMediaIds.filter(id => !newMediaIds.includes(id));

  const ownerId = newData?.userId || newData?.uid || oldData?.userId || oldData?.uid || "unknown_user";

  for (const mediaId of added) {
    await db.runTransaction(async (transaction) => {
      // 1. Create Media Reference
      const refId = `ref_${sourceType}_${docId}_${mediaId}`;
      const refDoc = db.collection("media_references").doc(refId);
      transaction.set(refDoc, {
        referenceId: refId,
        mediaId,
        ownerId,
        sourceType,
        sourceDocumentId: docId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Increment referenceCount
      const mediaRef = db.collection("media").doc(mediaId);
      transaction.update(mediaRef, {
        referenceCount: admin.firestore.FieldValue.increment(1),
        lastReferencedBy: ownerId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  for (const mediaId of removed) {
    await db.runTransaction(async (transaction) => {
      // 1. Delete Media Reference
      const refId = `ref_${sourceType}_${docId}_${mediaId}`;
      const refDoc = db.collection("media_references").doc(refId);
      transaction.delete(refDoc);

      // 2. Decrement referenceCount
      const mediaRef = db.collection("media").doc(mediaId);
      transaction.update(mediaRef, {
        referenceCount: admin.firestore.FieldValue.increment(-1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }
}

function extractMediaIds(data: any, sourceType: string): string[] {
  if (!data) return [];
  const ids: string[] = [];

  if (sourceType === "post" || sourceType === "story") {
    // Media array format
    const media = data.media || [];
    for (const item of media) {
      if (item.publicId) ids.push(item.publicId);
    }
    // Check main mediaUrl if story
    if (data.mediaUrl && data.mediaUrl.includes("/media/")) {
      const match = data.mediaUrl.match(/\/media\/([a-zA-Z0-9_]+)/);
      if (match && match[1]) ids.push(match[1].split(".")[0].split("_")[0]);
    }
  } else if (sourceType === "event") {
    // Banner mediaId
    if (data.bannerPublicId) ids.push(data.bannerPublicId);
  } else if (sourceType === "profile") {
    // Avatar and Cover photo URL paths
    if (data.avatarUrl && data.avatarUrl.includes("/media/")) {
      const match = data.avatarUrl.match(/\/media\/([a-zA-Z0-9_]+)/);
      if (match && match[1]) ids.push(match[1].split(".")[0].split("_")[0]);
    }
    if (data.coverUrl && data.coverUrl.includes("/media/")) {
      const match = data.coverUrl.match(/\/media\/([a-zA-Z0-9_]+)/);
      if (match && match[1]) ids.push(match[1].split(".")[0].split("_")[0]);
    }
  }
  return Array.from(new Set(ids));
}

// --- 3. Daily Scheduled Media Cleanup & Integrity sweeps ---

export const dailyMediaCleanup = functions.pubsub.schedule("every 24 hours").onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  const gracePeriod24h = new Date(now.toDate().getTime() - 24 * 60 * 60 * 1000);

  // A. Orphaned media sweep (referenceCount == 0 and status is pending_deletion / failed and not locked)
  const querySnap = await db.collection("media")
    .where("referenceCount", "==", 0)
    .where("isLocked", "==", false)
    .get();

  for (const mediaDoc of querySnap.docs) {
    const data = mediaDoc.data();
    const mediaId = mediaDoc.id;

    // Check if grace period is expired
    const updatedAt = data.updatedAt ? data.updatedAt.toDate() : new Date();
    if (updatedAt < gracePeriod24h) {
      console.log(`Orphan Detection: Deleting orphaned media ${mediaId}`);
      await permanentlyDeleteMedia(mediaId, data);
    }
  }

  // B. Repair job for references count check (Recalculate only if mismatch detected)
  const refsSnap = await db.collection("media_references").get();
  const counts: Record<string, number> = {};
  for (const ref of refsSnap.docs) {
    const mId = ref.data().mediaId;
    counts[mId] = (counts[mId] || 0) + 1;
  }

  const mediaSnap = await db.collection("media").get();
  for (const mDoc of mediaSnap.docs) {
    const mId = mDoc.id;
    const actualRefsCount = counts[mId] || 0;
    const reportedCount = mDoc.data().referenceCount || 0;

    if (actualRefsCount !== reportedCount) {
      console.warn(`Repair Job: referenceCount mismatch for media ${mId}. Fixed: ${reportedCount} -> ${actualRefsCount}`);
      await mDoc.ref.update({ referenceCount: actualRefsCount });
    }
  }

  // C. Delete staged files in R2 under temp/ older than 12 hours
  // This is handled by a direct Worker call or bucket policy on Cloudflare.
  console.log("Cleanup job finished successfully.");
});

async function permanentlyDeleteMedia(mediaId: string, mediaData: any) {
  // 1. Delete files in R2 bucket via Cloudflare Worker
  const isVideo = mediaData.mediaType === "video";
  const filesToDelete = isVideo 
    ? [`media/${mediaId}.mp4`, `media/${mediaId}_thumb.jpg`]
    : [`media/${mediaId}.webp`, `media/${mediaId}_thumb.webp`, `media/${mediaId}_feed.webp`];

  for (const key of filesToDelete) {
    try {
      const deleteUrl = `${WORKER_BASE_URL}/${key}`;
      await fetch(deleteUrl, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${ADMIN_SECRET}` },
      });
    } catch (e) {
      console.error(`Failed to delete key ${key} from R2:`, e);
    }
  }

  // 2. Delete Firestore documents in transaction
  const mediaRef = db.collection("media").doc(mediaId);
  await db.runTransaction(async (transaction) => {
    transaction.delete(mediaRef);
  });
}

async function triggerVideoProcessor(videoProcessorUrl: string, jobId: string, token: string) {
  try {
    const response = await fetch(videoProcessorUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ jobId }),
    });

    if (!response.ok) {
      throw new Error(`Processor HTTP trigger failed: ${await response.text()}`);
    }
  } catch (e: any) {
    console.error("Failed to trigger video processor:", e);
  }
}


