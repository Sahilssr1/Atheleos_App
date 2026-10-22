import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import { exec } from "child_process";
import { promisify } from "util";
import * as nodemailer from "nodemailer";

const execPromise = promisify(exec);
admin.initializeApp();
const db = admin.firestore();

// Worker API Configurations
const WORKER_BASE_URL = process.env.WORKER_BASE_URL || "https://atheleos-media-worker.atheleos-media.workers.dev";
const ADMIN_SECRET = process.env.ADMIN_SECRET_KEY || "atheleos-admin-secret-key-12345";

// --- 1. Video Processing HTTPS Trigger ---

const runtimeOpts = {
  timeoutSeconds: 300,
  memory: "2GB" as const,
};

export const processVideoJob = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
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
  const inputExt = path.extname(tempFilePath) || ".mp4";
  const localInputPath = path.join(tempDir, `${mediaId}_input${inputExt}`);
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
    // Scale preserving natural aspect ratio without adding any letterbox/pillarbox padding (pad=).
    // Keep a 1080p-class rendition so high-density phones and desktop do not receive
    // an unnecessarily soft 720p/1280px master. The -2 dimension keeps H.264 sizes even.
    const { stdout: inProbeJson } = await execPromise(
      `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,r_frame_rate -of json "${localInputPath}"`,
      { maxBuffer: 10 * 1024 * 1024 }
    );
    console.log(`[VIDEO JOB ${jobId}] Input Probe:`, inProbeJson.trim());

    // Scale preserving natural aspect ratio without letterbox/pillarbox padding.
    // Force square pixel aspect ratio (setsar=1) to eliminate anamorphic distortion.
    const scaleFilter = "scale='if(gte(iw,ih),min(1920,iw),-2)':'if(gte(iw,ih),-2,min(1920,ih))',setsar=1";

    // Main profile, no B-frames, and bounded references avoid known Android hardware
    // decoder stride/artifact failures while retaining high visual quality (CRF 20).
    const cmd = `ffmpeg -y -nostdin -i "${localInputPath}" -vf "${scaleFilter}" -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -profile:v main -level 4.1 -refs 2 -bf 0 -colorspace bt709 -color_primaries bt709 -color_trc bt709 -movflags +faststart -c:a aac -b:a 160k -ac 2 -t 180 "${localOutputPath}"`;
    await execPromise(cmd, { maxBuffer: 50 * 1024 * 1024 });

    // 3. Simple Thumbnail Generation & Probing directly from the optimized output video
    // (guarantees matching aspect ratio, upright orientation, and zero padding)
    const { stdout: outProbeJson } = await execPromise(
      `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,r_frame_rate,codec_name,pix_fmt,profile,level -of json "${localOutputPath}"`,
      { maxBuffer: 10 * 1024 * 1024 }
    );
    console.log(`[VIDEO JOB ${jobId}] Output Probe:`, outProbeJson.trim());

    const outMetadata = JSON.parse(outProbeJson);
    const outStream = outMetadata.streams?.[0] || {};
    if (outStream.codec_name !== "h264" || outStream.pix_fmt !== "yuv420p") {
      throw new Error(`Unsupported transcoder output: codec=${outStream.codec_name}, pix_fmt=${outStream.pix_fmt}`);
    }
    const finalWidth = parseInt(outStream.width, 10) || 720;
    const finalHeight = parseInt(outStream.height, 10) || 1280;
    const finalDuration = parseFloat(outStream.duration) || 0;
    if (finalWidth < 2 || finalHeight < 2 || finalDuration <= 0) {
      throw new Error("Transcoder produced invalid video metadata");
    }
    // Decode the generated file before publishing it, so malformed output is retried
    // instead of being exposed as a ready MP4 to device decoders.
    await execPromise(`ffmpeg -v error -xerror -nostdin -i "${localOutputPath}" -f null -`, {
      maxBuffer: 10 * 1024 * 1024,
    });
    let finalFps = 30;
    try {
      finalFps = eval(outStream.r_frame_rate || "30");
    } catch (_) {}

    const isPortrait = finalHeight >= finalWidth;
    const finalAspectRatio = finalHeight > 0 ? finalWidth / finalHeight : (isPortrait ? 9 / 16 : 16 / 9);
    console.log(`[VIDEO JOB ${jobId}] Parsed: width=${finalWidth}, height=${finalHeight}, isPortrait=${isPortrait}, aspect=${finalAspectRatio}`);

    const thumbFrameTime = finalDuration > 2 ? 1 : (finalDuration > 0 ? finalDuration * 0.3 : 0.5);
    const thumbCmd = `ffmpeg -y -nostdin -ss ${thumbFrameTime} -i "${localOutputPath}" -vframes 1 -q:v 2 "${localThumbPath}"`;
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
          duration: finalDuration,
          width: finalWidth,
          height: finalHeight,
          aspectRatio: finalAspectRatio,
          bitrate: Math.round((videoBuffer.length * 8) / (finalDuration || 1)),
          fps: finalFps,
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
    // Avatar and Cover photo URL paths (support photoUrl/avatarUrl and coverPhoto/coverUrl)
    const avatar = data.photoUrl || data.avatarUrl;
    if (avatar && typeof avatar === "string" && avatar.includes("/media/")) {
      const match = avatar.match(/\/media\/([a-zA-Z0-9_]+)/);
      if (match && match[1]) ids.push(match[1].split(".")[0].split("_")[0]);
    }
    const cover = data.coverPhoto || data.coverUrl;
    if (cover && typeof cover === "string" && cover.includes("/media/")) {
      const match = cover.match(/\/media\/([a-zA-Z0-9_]+)/);
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

  // B. Repair job for references count check (inspect only media modified in last 48 hours to avoid full collection scans)
  const twoDaysAgo = admin.firestore.Timestamp.fromDate(new Date(now.toDate().getTime() - 48 * 60 * 60 * 1000));
  const mediaSnap = await db.collection("media")
    .where("updatedAt", ">=", twoDaysAgo)
    .limit(200)
    .get();

  for (const mDoc of mediaSnap.docs) {
    const mId = mDoc.id;
    const refsSnap = await db.collection("media_references").where("mediaId", "==", mId).get();
    const actualRefsCount = refsSnap.size;
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

// --- 4. Scheduled Cleanup of Incomplete Registrations (DISABLED) ---
// Kept disabled so that no accounts, test profiles, or user data are ever touched or deleted.
/*
export const cleanupIncompleteAccounts = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (context) => {
    // Disabled to preserve all user accounts and data intact.
  });
*/

// --- 5. Real-Time Email OTP Dispatch (Hostinger SMTP) ---

const smtpTransporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.hostinger.com",
  port: parseInt(process.env.SMTP_PORT || "465", 10),
  secure: true,
  auth: {
    user: process.env.SMTP_USER || "contact@atheleos.in",
    pass: process.env.SMTP_PASS || "Atheleos@5477",
  },
});

async function dispatchOtpEmail(toEmail: string, otpCode: string): Promise<boolean> {
  const htmlContent = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0a0a0a; color: #ffffff; padding: 40px 16px; text-align: center;">
      <div style="max-width: 480px; margin: 0 auto; background-color: #141414; border: 1px solid #282828; border-radius: 16px; padding: 36px 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.6);">
        <h1 style="color: #00E5FF; font-size: 26px; letter-spacing: 3px; margin: 0 0 6px 0; font-weight: 900;">ATHELEOS</h1>
        <p style="color: #777777; font-size: 12px; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 28px 0; font-weight: 700;">Arena Verification</p>
        
        <div style="background: linear-gradient(180deg, #181818 0%, #101010 100%); border: 1px solid #333333; border-radius: 12px; padding: 24px 16px; margin-bottom: 24px;">
          <p style="color: #aaaaaa; font-size: 14px; margin: 0 0 14px 0;">Use this 6-digit code to verify your email:</p>
          <div style="font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #00E5FF; font-family: monospace; padding-left: 10px;">${otpCode}</div>
          <p style="color: #666666; font-size: 12px; margin: 14px 0 0 0;">Valid for 10 minutes &bull; Single use only</p>
        </div>
        
        <p style="color: #999999; font-size: 13px; line-height: 1.5; margin: 0 0 24px 0;">
          Enter this verification code in the Atheleos mobile application to continue setting up your athlete profile.
        </p>
        
        <div style="border-top: 1px solid #222222; padding-top: 20px;">
          <p style="color: #555555; font-size: 11px; margin: 0; line-height: 1.4;">
            If you did not request this email, no further action is required.<br/>
            &copy; ${new Date().getFullYear()} Atheleos Arena. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  `;

  const info = await smtpTransporter.sendMail({
    from: `"Atheleos Arena" <contact@atheleos.in>`,
    to: toEmail,
    subject: `${otpCode} is your Atheleos verification code`,
    text: `Your Atheleos verification code is ${otpCode}. This code is valid for 10 minutes.`,
    html: htmlContent,
  });

  console.log(`[Email OTP] Successfully dispatched code to ${toEmail}. Message ID: ${info.messageId}`);
  return true;
}

// 5A. Direct HTTPS Endpoint for instant mobile dispatch
export const sendEmailOtp = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { email, code } = req.body || {};
  if (!email || !code) {
    res.status(400).json({ error: "Missing required email or code" });
    return;
  }

  const cleanEmail = String(email).trim().toLowerCase();
  const cleanCode = String(code).trim();

  try {
    await dispatchOtpEmail(cleanEmail, cleanCode);
    res.status(200).json({ success: true, message: `Verification code sent to ${cleanEmail}` });
  } catch (err: any) {
    console.error(`[sendEmailOtp] Error sending to ${cleanEmail}:`, err);
    res.status(500).json({ error: err.message || "Failed to send email verification code" });
  }
});

// 5B. Firestore Document Trigger Fallback
export const onEmailOtpWrite = functions.firestore
  .document("email_otps/{email}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const data = change.after.data();
    if (!data) return null;

    // Avoid duplicate sending if already marked sent
    if (data.status === "sent") return null;

    const email = data.email || context.params.email;
    const code = data.code;

    if (!email || !code) return null;

    try {
      await dispatchOtpEmail(email, code);
      await change.after.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    } catch (err: any) {
      console.error(`[onEmailOtpWrite] Failed for ${email}:`, err);
      await change.after.ref.update({
        status: "failed",
        error: String(err?.message || err),
      });
      return false;
    }
  });

// 5C. Reset Password with Verified OTP
export const resetPasswordWithOtp = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { email, code, newPassword } = req.body || {};
  if (!email || !code || !newPassword) {
    res.status(400).json({ error: "Missing required email, code, or newPassword" });
    return;
  }

  const cleanEmail = String(email).trim().toLowerCase();
  const cleanCode = String(code).trim();
  const passwordStr = String(newPassword);

  if (passwordStr.length < 8) {
    res.status(400).json({ error: "Password must be at least 8 characters long" });
    return;
  }
  if (!/[A-Z]/.test(passwordStr)) {
    res.status(400).json({ error: "Password must contain at least one uppercase letter (A-Z)" });
    return;
  }
  if (!/[a-z]/.test(passwordStr)) {
    res.status(400).json({ error: "Password must contain at least one lowercase letter (a-z)" });
    return;
  }
  if (!/[0-9]/.test(passwordStr)) {
    res.status(400).json({ error: "Password must contain at least one number (0-9)" });
    return;
  }
  if (!/[!@#$%^&*(),.?":{}|<>_+\-=\[\]\\\/~`]/.test(passwordStr)) {
    res.status(400).json({ error: "Password must contain at least one special character (!@#$%...)" });
    return;
  }

  try {
    // 1. Verify OTP in Firestore
    const otpDoc = await admin.firestore().collection("email_otps").doc(cleanEmail).get();
    if (!otpDoc.exists) {
      res.status(400).json({ error: "No OTP found for this email. Please request a new code." });
      return;
    }

    const data = otpDoc.data();
    if (!data || String(data.code).trim() !== cleanCode) {
      res.status(400).json({ error: "Invalid verification code. Please check and try again." });
      return;
    }

    const expiresAt = data.expiresAt ? data.expiresAt.toDate() : null;
    if (expiresAt && new Date() > expiresAt) {
      res.status(400).json({ error: "Verification code has expired. Please request a new one." });
      return;
    }

    // 2. Find Firebase Auth user
    let userRecord: admin.auth.UserRecord | null = null;
    try {
      userRecord = await admin.auth().getUserByEmail(cleanEmail);
    } catch (e: any) {
      // Check if user has this email stored as alternateEmail
      const userSnap = await admin.firestore().collection("users")
        .where("alternateEmail", "==", cleanEmail)
        .limit(1)
        .get();

      if (!userSnap.empty) {
        const uid = userSnap.docs[0].id;
        userRecord = await admin.auth().getUser(uid);
      } else {
        res.status(404).json({ error: "No registered Atheleos account found with this email." });
        return;
      }
    }

    if (!userRecord) {
      res.status(404).json({ error: "User account could not be found." });
      return;
    }

    // 3. Update the password in Firebase Authentication
    await admin.auth().updateUser(userRecord.uid, {
      password: passwordStr,
    });

    // 4. Mark the OTP as used
    await otpDoc.ref.update({
      verified: true,
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[resetPasswordWithOtp] Successfully updated password for user ${userRecord.uid} (${cleanEmail})`);
    res.status(200).json({ success: true, message: "Password updated successfully" });
  } catch (err: any) {
    console.error(`[resetPasswordWithOtp] Error updating password for ${cleanEmail}:`, err);
    res.status(500).json({ error: err.message || "Failed to reset password. Please try again." });
  }
});

// 5D. Cleanup Incomplete / Orphan Registration Account
export const cleanupIncompleteAccount = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { email } = req.body || {};
  if (!email) {
    res.status(400).json({ error: "Missing required email parameter" });
    return;
  }

  const cleanEmail = String(email).trim().toLowerCase();

  try {
    // 1. Check if user exists in Firebase Auth
    let userRecord: admin.auth.UserRecord | null = null;
    try {
      userRecord = await admin.auth().getUserByEmail(cleanEmail);
    } catch (e: any) {
      if (e.code === "auth/user-not-found") {
        res.status(200).json({ success: true, deletedOrphan: false, message: "No auth user found for this email." });
        return;
      }
      throw e;
    }

    if (!userRecord) {
      res.status(200).json({ success: true, deletedOrphan: false, message: "No auth user found." });
      return;
    }

    const uid = userRecord.uid;

    // 2. Check if a completed Firestore profile exists for this UID or email
    const userDocSnap = await admin.firestore().collection("users").doc(uid).get();

    const altEmailSnap = await admin.firestore().collection("users")
      .where("alternateEmail", "==", cleanEmail)
      .limit(1)
      .get();
    const primaryEmailSnap = await admin.firestore().collection("users")
      .where("email", "==", cleanEmail)
      .limit(1)
      .get();

    const existingDoc = userDocSnap.exists
      ? userDocSnap
      : (!altEmailSnap.empty ? altEmailSnap.docs[0] : (!primaryEmailSnap.empty ? primaryEmailSnap.docs[0] : null));

    if (existingDoc && existingDoc.exists) {
      const data = existingDoc.data() || {};
      // If user has phoneVerified === true AND has role, it is a completed user!
      if (data.phoneVerified === true && data.role && String(data.role).trim().length > 0) {
        res.status(200).json({
          success: false,
          completed: true,
          message: "This account has a completed profile.",
        });
        return;
      }
    }

    // 3. Incomplete / orphan registration: Purge partial data and delete the Firebase Auth user!
    if (existingDoc && existingDoc.exists) {
      const data = existingDoc.data() || {};
      if (data.username) {
        try {
          await admin.firestore().collection("usernames").doc(String(data.username).toLowerCase().trim()).delete();
        } catch (_) {}
      }
      try {
        await existingDoc.ref.delete();
      } catch (_) {}
    }
    if (userDocSnap.exists) {
      try {
        await userDocSnap.ref.delete();
      } catch (_) {}
    }

    // Delete the orphan Firebase Auth user
    await admin.auth().deleteUser(uid);
    console.log(`[cleanupIncompleteAccount] Successfully purged orphan user ${uid} (${cleanEmail})`);

    res.status(200).json({
      success: true,
      deletedOrphan: true,
      message: "Successfully deleted incomplete account.",
    });
  } catch (err: any) {
    console.error(`[cleanupIncompleteAccount] Error for ${cleanEmail}:`, err);
    res.status(500).json({ error: err.message || "Failed to cleanup incomplete account" });
  }
});




