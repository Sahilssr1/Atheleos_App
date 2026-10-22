export interface Env {
  R2_BUCKET: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  WORKER_VERSION: string;
  PIPELINE_VERSION: string;
  VIDEO_PROCESSOR_URL: string;
  MAX_UPLOADS_PER_HOUR: string;
  MAX_UPLOADS_PER_DAY: string;
  ADMIN_SECRET_KEY?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Owner-Type, X-Idempotency-Key, X-File-Name, X-File-Size",
        },
      });
    }

    try {
      // 1. Public endpoints (bypasses Auth entirely)
      if (url.pathname.startsWith("/media/") && request.method === "GET") {
        return handleGetMedia(request, env);
      }
      if (url.pathname.startsWith("/temp/") && request.method === "GET") {
        return handleGetTempMedia(request, env);
      }

      // 2. Auth Header validation
      const authHeader = request.headers.get("Authorization");
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return jsonResponse({ error: "Unauthorized. Missing or invalid Authorization header." }, 401);
      }
      const token = authHeader.substring(7);

      // Check if Admin (strictly requires non-empty ADMIN_SECRET_KEY in environment)
      const adminSecret = env.ADMIN_SECRET_KEY;
      const isAdmin = Boolean(adminSecret && adminSecret.length >= 16 && token === adminSecret);

      let user: any = null;
      if (!isAdmin) {
        user = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
        if (!user) {
          return jsonResponse({ error: "Unauthorized. Invalid Firebase token." }, 401);
        }
      }

      // 3. Authenticated routes
      // POST /upload (Client file staging)
      if (url.pathname === "/upload" && request.method === "POST") {
        return handleUpload(request, env, user, token, ctx);
      }

      // POST /upload/cancel (Client cancel upload)
      if (url.pathname === "/upload/cancel" && request.method === "POST") {
        return handleCancelUpload(request, env, user);
      }

      // GET /upload/check/:hash (Client check deduplication)
      if (url.pathname.startsWith("/upload/check/") && request.method === "GET") {
        const hash = url.pathname.split("/")[3];
        return handleCheckDeduplication(request, env, user, hash, token);
      }

      // PUT /media/:filename (Admin transcoder upload)
      if (url.pathname.startsWith("/media/") && request.method === "PUT") {
        if (!isAdmin) return jsonResponse({ error: "Forbidden. Admin only." }, 403);
        const filename = url.pathname.split("/")[2];
        return handleAdminUpload(request, env, filename);
      }

      // DELETE /temp/:filename (Admin temp cleanup)
      if (url.pathname.startsWith("/temp/") && request.method === "DELETE") {
        if (!isAdmin) return jsonResponse({ error: "Forbidden. Admin only." }, 403);
        const filename = url.pathname.split("/")[2];
        return handleAdminDeleteTemp(request, env, filename);
      }

      // DELETE /media/:filename (Admin permanent delete OR user soft delete)
      if (url.pathname.startsWith("/media/") && request.method === "DELETE") {
        const mediaId = url.pathname.split("/")[2];
        if (isAdmin) {
          return handleAdminDeleteMedia(request, env, mediaId);
        } else {
          return handleDeleteMedia(request, env, user, mediaId, token);
        }
      }

      return jsonResponse({ error: "Not Found" }, 404);
    } catch (e: any) {
      console.error("Worker Global Error:", e);
      return jsonResponse({ error: e.message || "Internal Server Error" }, 500);
    }
  },
};

// --- REST API helpers for Firestore ---

async function firestoreRequest(
  method: string,
  path: string,
  token: string,
  body?: any
): Promise<any> {
  const url = `https://firestore.googleapis.com/v1/projects/${path}`;
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore API error (${response.status}): ${errText}`);
  }

  return response.json();
}

// --- Handler Functions ---

async function handleGetMedia(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const pathParts = url.pathname.split("/");
  const filename = pathParts[pathParts.length - 1]; // e.g. mediaId.mp4 or mediaId_thumb.webp

  const rangeHeader = request.headers.get("Range");
  let range: R2Range | undefined;
  if (rangeHeader) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
    if (!match || (!match[1] && !match[2])) {
      return new Response("Invalid Range", { status: 416 });
    }
    const start = match[1] ? Number(match[1]) : undefined;
    const end = match[2] ? Number(match[2]) : undefined;
    range = start === undefined
      ? { suffix: end! }
      : { offset: start, ...(end === undefined ? {} : { length: end - start + 1 }) };
  }

  const object = await env.R2_BUCKET.get(`media/${filename}`, range ? { range } : undefined);
  if (!object) {
    return new Response("Media not found", { status: 404 });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Accept-Ranges", "bytes");
  
  // Set cache headers depending on variant
  if (filename.includes("_thumb.") || filename.includes("_feed.") || filename.endsWith(".webp")) {
    // Images are immutable
    headers.set("Cache-Control", "public, max-age=31536000, immutable");
  } else {
    // Video streaming cache (e.g. 1 month)
    headers.set("Cache-Control", "public, max-age=2592000");
  }

  if (rangeHeader && object.range) {
    const offset = object.range.offset;
    const length = object.range.length;
    headers.set("Content-Range", `bytes ${offset}-${offset + length - 1}/${object.size}`);
    headers.set("Content-Length", String(length));
    return new Response(object.body, { status: 206, headers });
  }
  headers.set("Content-Length", String(object.size));
  return new Response(object.body, { headers });
}

async function handleUpload(
  request: Request,
  env: Env,
  user: any,
  token: string,
  ctx: ExecutionContext
): Promise<Response> {
  const contentType = request.headers.get("Content-Type") || "";
  if (!contentType.includes("multipart/form-data")) {
    return jsonResponse({ error: "Invalid Content-Type. Must be multipart/form-data" }, 400);
  }

  const ownerType = request.headers.get("X-Owner-Type") || "post";
  const idempotencyKey = request.headers.get("X-Idempotency-Key") || "";
  const fileName = request.headers.get("X-File-Name") || "upload.dat";
  const fileSizeStr = request.headers.get("X-File-Size");
  const fileSize = fileSizeStr ? parseInt(fileSizeStr, 10) : 0;

  if (!idempotencyKey) {
    return jsonResponse({ error: "Missing X-Idempotency-Key header" }, 400);
  }

  // 1. Check idempotency: Query processing_jobs to see if key already exists
  const existingJob = await findJobByIdempotencyKey(env, token, idempotencyKey);
  if (existingJob) {
    if (existingJob.status === "completed") {
      const mediaDoc = await getMediaDoc(env, token, existingJob.mediaId);
      return jsonResponse({ status: "success", media: mediaDoc });
    } else if (existingJob.status === "running" || existingJob.status === "pending") {
      return jsonResponse({ status: "processing", jobId: existingJob.jobId, mediaId: existingJob.mediaId });
    }
  }

  // 2. Parse Multipart form to get the file
  const formData = await request.formData();
  const file = formData.get("file") as unknown as File;
  if (!file) {
    return jsonResponse({ error: "No file payload in request" }, 400);
  }

  const bytes = new Uint8Array(await file.arrayBuffer());
  const actualSize = bytes.length;

  // Validate file limits
  let mime = file.type;
  if (!mime || mime === "application/octet-stream") {
    mime = getMimeFromFilename(fileName);
  }
  const isVideo = mime.startsWith("video/");
  const maxLimit = isVideo ? 250 * 1024 * 1024 : 20 * 1024 * 1024; // 250MB / 20MB
  if (actualSize > maxLimit) {
    return jsonResponse({ error: `File size exceeds limit (${isVideo ? "250MB for video" : "20MB for image"})` }, 400);
  }

  // Verify Magic Bytes
  if (!validateMagicBytes(bytes, mime)) {
    return jsonResponse({ error: "File signature validation failed. Spoofed file format." }, 400);
  }

  // 3. Compute SHA-256 hash
  const hashBuffer = await crypto.subtle.digest("SHA-256", bytes);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const mediaHash = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

  // 4. Check for Deduplication
  const existingMedia = await findMediaByHash(env, token, mediaHash);
  if (existingMedia && existingMedia.status === "ready") {
    // Atomic increment reference count on backend and insert audit log
    await registerReference(env, token, existingMedia.mediaId, user.uid, ownerType);
    return jsonResponse({ status: "success", media: existingMedia });
  }

  // 5. Create new Media Document in Firestore
  const mediaId = "med_" + Math.random().toString(36).substring(2, 15);

  const isGif = mime === "image/gif";
  if (isGif) {
    const r2Key = `media/${mediaId}.gif`;
    await env.R2_BUCKET.put(r2Key, bytes, {
      httpMetadata: { contentType: "image/gif" },
    });

    const urlObj = new URL(request.url);
    const baseUrl = `${urlObj.protocol}//${urlObj.host}`;
    const gifUrl = `${baseUrl}/media/${mediaId}.gif`;

    const mediaDoc = {
      fields: {
        mediaId: { stringValue: mediaId },
        mediaHash: { stringValue: mediaHash },
        mediaType: { stringValue: "image" },
        ownerType: { stringValue: ownerType },
        status: { stringValue: "ready" },
        storageClass: { stringValue: "hot" },
        isLocked: { booleanValue: false },
        version: { integerValue: "1" },
        isActive: { booleanValue: true },
        referenceCount: { integerValue: "0" },
        createdBy: { stringValue: user.uid },
        urls: {
          mapValue: {
            fields: {
              original: { stringValue: gifUrl },
              thumbnail: { stringValue: gifUrl },
              feed: { stringValue: gifUrl },
            },
          },
        },
        sizes: {
          mapValue: {
            fields: {
              original: { integerValue: String(bytes.length) },
            },
          },
        },
        createdAt: { timestampValue: new Date().toISOString() },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };

    // Create Media Document
    await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media?documentId=${mediaId}`, token, mediaDoc);

    // Create Processing Job
    const jobId = "job_" + Math.random().toString(36).substring(2, 15);
    const jobDoc = {
      fields: {
        jobId: { stringValue: jobId },
        mediaId: { stringValue: mediaId },
        idempotencyKey: { stringValue: idempotencyKey },
        status: { stringValue: "completed" },
        retryCount: { integerValue: "0" },
        tempFilePath: { stringValue: "" },
        limits: {
          mapValue: {
            fields: {
              maxDurationSeconds: { integerValue: "0" },
              maxFileSize: { integerValue: String(maxLimit) },
            },
          },
        },
        summary: {
          mapValue: {
            fields: {
              startedAt: { timestampValue: new Date().toISOString() },
              completedAt: { timestampValue: new Date().toISOString() },
            },
          },
        },
        createdBy: { stringValue: user.uid },
        workerVersion: { stringValue: env.WORKER_VERSION },
        pipelineVersion: { stringValue: env.PIPELINE_VERSION },
        createdAt: { timestampValue: new Date().toISOString() },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };

    await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/processing_jobs?documentId=${jobId}`, token, jobDoc);

    // Register reference link
    await registerReference(env, token, mediaId, user.uid, ownerType);

    const finalMedia = await getMediaDoc(env, token, mediaId);
    return jsonResponse({ status: "success", media: finalMedia });
  }

  if (!isVideo) {
    const isPdf = mime === "application/pdf" || (fileName && fileName.toLowerCase().endsWith(".pdf"));
    const fileExt = isPdf ? "pdf" : "webp";
    const contentType = isPdf ? "application/pdf" : "image/webp";
    const mediaTypeStr = isPdf ? "document" : "image";

    // 1. Immediately write original bytes to R2 to make it available
    const r2Key = `media/${mediaId}.${fileExt}`;
    await env.R2_BUCKET.put(r2Key, bytes, {
      httpMetadata: { contentType },
    });

    const urlObj = new URL(request.url);
    const baseUrl = `${urlObj.protocol}//${urlObj.host}`;
    const fileUrl = `${baseUrl}/media/${mediaId}.${fileExt}`;

    const mediaDoc = {
      fields: {
        mediaId: { stringValue: mediaId },
        mediaHash: { stringValue: mediaHash },
        mediaType: { stringValue: mediaTypeStr },
        ownerType: { stringValue: ownerType },
        status: { stringValue: "ready" },
        storageClass: { stringValue: "hot" },
        isLocked: { booleanValue: false },
        version: { integerValue: "1" },
        isActive: { booleanValue: true },
        referenceCount: { integerValue: "0" },
        createdBy: { stringValue: user.uid },
        urls: {
          mapValue: {
            fields: {
              original: { stringValue: fileUrl },
              thumbnail: { stringValue: fileUrl },
              feed: { stringValue: fileUrl },
            },
          },
        },
        sizes: {
          mapValue: {
            fields: {
              original: { integerValue: String(bytes.length) },
            },
          },
        },
        createdAt: { timestampValue: new Date().toISOString() },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };

    // Create Media Document
    await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media?documentId=${mediaId}`, token, mediaDoc);

    // Create Processing Job
    const jobId = "job_" + Math.random().toString(36).substring(2, 15);
    const jobDoc = {
      fields: {
        jobId: { stringValue: jobId },
        mediaId: { stringValue: mediaId },
        idempotencyKey: { stringValue: idempotencyKey },
        status: { stringValue: "completed" },
        retryCount: { integerValue: "0" },
        tempFilePath: { stringValue: "" },
        limits: {
          mapValue: {
            fields: {
              maxDurationSeconds: { integerValue: "0" },
              maxFileSize: { integerValue: String(maxLimit) },
            },
          },
        },
        summary: {
          mapValue: {
            fields: {
              startedAt: { timestampValue: new Date().toISOString() },
              completedAt: { timestampValue: new Date().toISOString() },
            },
          },
        },
        createdBy: { stringValue: user.uid },
        workerVersion: { stringValue: env.WORKER_VERSION },
        pipelineVersion: { stringValue: env.PIPELINE_VERSION },
        createdAt: { timestampValue: new Date().toISOString() },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };

    await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/processing_jobs?documentId=${jobId}`, token, jobDoc);

    // Register reference link
    await registerReference(env, token, mediaId, user.uid, ownerType);

    // Trigger background image resizing optimization (runs asynchronously)
    ctx.waitUntil(optimizeImageInBackground(env, bytes, mediaId, user.uid, token, request));

    const finalMedia = await getMediaDoc(env, token, mediaId);
    return jsonResponse({ status: "success", media: finalMedia });
  }

  const rawExt = fileName.split(".").pop()?.toLowerCase();
  const validVideoExts = ["mp4", "mov", "webm", "mkv", "3gp", "m4v", "avi"];
  const safeExt = isVideo ? (rawExt && validVideoExts.includes(rawExt) ? rawExt : "mp4") : "webp";
  const tempPath = `temp/${mediaId}_temp.${safeExt}`;

  // Stage in R2 bucket
  await env.R2_BUCKET.put(tempPath, bytes, {
    httpMetadata: {
      contentType: mime,
    },
    customMetadata: {
      createdBy: user.uid,
      mediaId,
    },
  });

  const mediaDoc = {
    fields: {
      mediaId: { stringValue: mediaId },
      mediaHash: { stringValue: mediaHash },
      mediaType: { stringValue: isVideo ? "video" : "image" },
      ownerType: { stringValue: ownerType },
      status: { stringValue: "processing" },
      storageClass: { stringValue: "hot" },
      isLocked: { booleanValue: false },
      version: { integerValue: "1" },
      isActive: { booleanValue: true },
      referenceCount: { integerValue: "0" },
      createdBy: { stringValue: user.uid },
      createdAt: { timestampValue: new Date().toISOString() },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };

  // Create Media Document
  await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media?documentId=${mediaId}`, token, mediaDoc);

  // 6. Create Processing Job
  const jobId = "job_" + Math.random().toString(36).substring(2, 15);
  const jobDoc = {
    fields: {
      jobId: { stringValue: jobId },
      mediaId: { stringValue: mediaId },
      idempotencyKey: { stringValue: idempotencyKey },
      status: { stringValue: isVideo ? "pending" : "completed" },
      retryCount: { integerValue: "0" },
      tempFilePath: { stringValue: tempPath },
      limits: {
        mapValue: {
          fields: {
            maxDurationSeconds: { integerValue: isVideo ? "180" : "0" },
            maxFileSize: { integerValue: String(maxLimit) },
          },
        },
      },
      summary: {
        mapValue: {
          fields: {
            startedAt: { timestampValue: new Date().toISOString() },
          },
        },
      },
      createdBy: { stringValue: user.uid },
      workerVersion: { stringValue: env.WORKER_VERSION },
      pipelineVersion: { stringValue: env.PIPELINE_VERSION },
      createdAt: { timestampValue: new Date().toISOString() },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };

  await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/processing_jobs?documentId=${jobId}`, token, jobDoc);

  // Register reference link
  await registerReference(env, token, mediaId, user.uid, ownerType);

  if (!isVideo) {
    // Synchronous Image Optimization inside Worker
    try {
      await optimizeImageInWorker(env, bytes, mediaId, user.uid, token, request);
    } catch (e: any) {
      console.error("Image optimization error:", e);
      // Mark media and job as failed
      await markMediaFailed(env, token, mediaId, jobId, e.message);
      return jsonResponse({ error: "Image processing failed: " + e.message }, 500);
    }
    const finalMedia = await getMediaDoc(env, token, mediaId);
    return jsonResponse({ status: "success", media: finalMedia });
  } else {
    // Video asynchronous transcoding: trigger Firebase Cloud Function and return job details
    ctx.waitUntil(triggerVideoProcessor(env, jobId, token));
    return jsonResponse({ status: "processing", jobId, mediaId });
  }
}

async function handleDeleteMedia(
  request: Request,
  env: Env,
  user: any,
  mediaId: string,
  token: string
): Promise<Response> {
  // Validate ownership/admin permissions and soft deletion eligibility
  const mediaDoc = await getMediaDoc(env, token, mediaId);
  if (!mediaDoc) {
    return jsonResponse({ error: "Media not found" }, 404);
  }

  if (mediaDoc.createdBy !== user.uid) {
    return jsonResponse({ error: "Forbidden. You do not own this media." }, 403);
  }

  // Soft delete by updating status to pending_deletion and scheduling cleanup
  const updatedMedia = {
    fields: {
      ...convertToFirestoreFields(mediaDoc),
      status: { stringValue: "pending_deletion" },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };

  await firestoreRequest("PATCH", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media/${mediaId}?updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt`, token, updatedMedia);
  return jsonResponse({ status: "success", message: "Media soft-deleted successfully" });
}

// --- Image Optimization Implementation (WebP conversion + resizing) ---

async function optimizeImageInBackground(
  env: Env,
  bytes: Uint8Array,
  mediaId: string,
  uid: string,
  token: string,
  request: Request
) {
  try {
    const tempPath = `temp/${mediaId}_temp.webp`;
    await env.R2_BUCKET.put(tempPath, bytes, {
      httpMetadata: { contentType: "image/webp" },
    });
    await optimizeImageInWorker(env, bytes, mediaId, uid, token, request);
  } catch (e) {
    console.error("Background image optimization failed:", e);
  }
}

async function optimizeImageInWorker(
  env: Env,
  bytes: Uint8Array,
  mediaId: string,
  uid: string,
  token: string,
  request: Request
) {
  let thumbBytes = bytes;
  let feedBytes = bytes;
  let fullBytes = bytes;

  const urlObj = new URL(request.url);
  const baseUrl = `${urlObj.protocol}//${urlObj.host}`;
  const tempUrl = `${baseUrl}/temp/${mediaId}_temp.webp`;

  try {
    // Generate Thumbnail variant (~150px)
    const thumbRes = await fetch(tempUrl, {
      cf: { image: { width: 150, format: 'webp', quality: 80 } }
    } as any);
    if (thumbRes.status === 200) {
      thumbBytes = new Uint8Array(await thumbRes.arrayBuffer());
    }

    // Generate Feed variant (~480px)
    const feedRes = await fetch(tempUrl, {
      cf: { image: { width: 480, format: 'webp', quality: 80 } }
    } as any);
    if (feedRes.status === 200) {
      feedBytes = new Uint8Array(await feedRes.arrayBuffer());
    }

    // Generate Full variant (~720px)
    const fullRes = await fetch(tempUrl, {
      cf: { image: { width: 720, format: 'webp', quality: 80 } }
    } as any);
    if (fullRes.status === 200) {
      fullBytes = new Uint8Array(await fullRes.arrayBuffer());
    }
  } catch (e) {
    console.warn("Cloudflare Image Resizing failed or not available, falling back to original image bytes.", e);
  }

  const r2Key = `media/${mediaId}.webp`;
  await env.R2_BUCKET.put(r2Key, fullBytes, {
    httpMetadata: { contentType: "image/webp" },
  });

  const thumbKey = `media/${mediaId}_thumb.webp`;
  await env.R2_BUCKET.put(thumbKey, thumbBytes, {
    httpMetadata: { contentType: "image/webp" },
  });

  const feedKey = `media/${mediaId}_feed.webp`;
  await env.R2_BUCKET.put(feedKey, feedBytes, {
    httpMetadata: { contentType: "image/webp" },
  });

  // Delete temp staged file
  await env.R2_BUCKET.delete(`temp/${mediaId}_temp.webp`);

  // Update Media Document in Firestore to ready status and add URLs
  const baseUrlForUrl = `${baseUrl}/media/${mediaId}`;
  const updatedMedia = {
    fields: {
      status: { stringValue: "ready" },
      urls: {
        mapValue: {
          fields: {
            original: { stringValue: baseUrlForUrl + ".webp" },
            thumbnail: { stringValue: baseUrlForUrl + "_thumb.webp" },
            feed: { stringValue: baseUrlForUrl + "_feed.webp" },
          },
        },
      },
      sizes: {
        mapValue: {
          fields: {
            original: { integerValue: String(bytes.length) },
            optimized: {
              mapValue: {
                fields: {
                  originalVariant: { integerValue: String(fullBytes.length) },
                  thumbnail: { integerValue: String(thumbBytes.length) },
                  feed: { integerValue: String(feedBytes.length) },
                },
              },
            },
          },
        },
      },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };

  // Run patch request
  await firestoreRequest(
    "PATCH",
    `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media/${mediaId}?updateMask.fieldPaths=status&updateMask.fieldPaths=urls&updateMask.fieldPaths=sizes&updateMask.fieldPaths=updatedAt`,
    token,
    updatedMedia
  );
}

// --- Video Transcoder HTTP trigger ---

async function triggerVideoProcessor(env: Env, jobId: string, token: string) {
  try {
    const response = await fetch(env.VIDEO_PROCESSOR_URL, {
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

interface GoogleJwkKey {
  kid: string;
  alg: string;
  kty: string;
  n: string;
  e: string;
  use?: string;
}

let _cachedJwks: { keys: GoogleJwkKey[] } | null = null;
let _jwksCachedAt = 0;
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour cache

function base64UrlToUint8Array(base64Url: string): Uint8Array {
  let base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4) {
    base64 += "=";
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function parseBase64UrlJson(base64Url: string): any {
  let base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4) {
    base64 += "=";
  }
  return JSON.parse(atob(base64));
}

async function getGoogleJwks(): Promise<GoogleJwkKey[]> {
  const now = Date.now();
  if (_cachedJwks && now - _jwksCachedAt < JWKS_TTL_MS) {
    return _cachedJwks.keys;
  }
  try {
    const res = await fetch("https://www.googleapis.com/service_accounts/v1/jwk/securetoken-system-uid");
    if (!res.ok) throw new Error("Failed to fetch Google JWKS");
    _cachedJwks = await res.json() as { keys: GoogleJwkKey[] };
    _jwksCachedAt = now;
    return _cachedJwks.keys;
  } catch (err) {
    if (_cachedJwks) return _cachedJwks.keys;
    throw err;
  }
}

async function verifyFirebaseToken(token: string, projectId: string): Promise<any> {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    // 1. Parse header and extract Key ID (kid)
    const header = parseBase64UrlJson(parts[0]);
    if (header.alg !== "RS256" || !header.kid) return null;

    // 2. Parse payload and validate claims
    const payload = parseBase64UrlJson(parts[1]);
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
    if (payload.aud !== projectId) return null;
    if (payload.exp < Date.now() / 1000) return null;

    // 3. Match kid with Google public JWK
    const jwks = await getGoogleJwks();
    const matchingKey = jwks.find(k => k.kid === header.kid);
    if (!matchingKey) return null;

    // 4. Import public RSA key into Web Crypto API
    const cryptoKey = await crypto.subtle.importKey(
      "jwk",
      matchingKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    // 5. Cryptographically verify signature
    const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const signature = base64UrlToUint8Array(parts[2]);
    const isValid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, signature, data);
    if (!isValid) return null;

    return { uid: payload.sub, email: payload.email };
  } catch (e) {
    console.error("verifyFirebaseToken signature verification failed:", e);
    return null;
  }
}

function validateMagicBytes(bytes: Uint8Array, mime: string): boolean {
  if (bytes.length < 4) return false;
  const hex = Array.from(bytes.slice(0, 4)).map(b => b.toString(16).padStart(2, "0")).join("").toUpperCase();

  if (mime.startsWith("image/jpeg")) {
    return hex.startsWith("FFD8FF");
  }
  if (mime.startsWith("image/png")) {
    return hex.startsWith("89504E47");
  }
  if (mime.startsWith("image/webp")) {
    return hex.startsWith("52494646"); // RIFF
  }
  if (mime.startsWith("application/pdf")) {
    return hex.startsWith("25504446"); // %PDF
  }
  if (mime.startsWith("video/")) {
    // Valid video streams (MP4/MOV ftyp, Matroska/WebM EBML, AVI RIFF, etc.)
    return true;
  }
  return true;
}

function getMimeFromFilename(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase();
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  if (ext === "png") return "image/png";
  if (ext === "webp") return "image/webp";
  if (ext === "gif") return "image/gif";
  if (ext === "mp4" || ext === "m4v") return "video/mp4";
  if (ext === "mov" || ext === "quicktime") return "video/quicktime";
  if (ext === "webm") return "video/webm";
  if (ext === "mkv") return "video/x-matroska";
  if (ext === "3gp" || ext === "3gpp") return "video/3gpp";
  if (ext === "avi") return "video/x-msvideo";
  if (ext === "pdf") return "application/pdf";
  return "application/octet-stream";
}

// --- Query helpers ---

async function findJobByIdempotencyKey(env: Env, token: string, key: string): Promise<any> {
  const body = {
    structuredQuery: {
      from: [{ collectionId: "processing_jobs" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "idempotencyKey" },
          op: "EQUAL",
          value: { stringValue: key },
        },
      },
      limit: 1,
    },
  };

  const results = await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`, token, body);
  if (results && results[0] && results[0].document) {
    return parseFirestoreDocument(results[0].document);
  }
  return null;
}

async function findMediaByHash(env: Env, token: string, hash: string): Promise<any> {
  const body = {
    structuredQuery: {
      from: [{ collectionId: "media" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "mediaHash" },
          op: "EQUAL",
          value: { stringValue: hash },
        },
      },
      limit: 1,
    },
  };

  const results = await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`, token, body);
  if (results && results[0] && results[0].document) {
    return parseFirestoreDocument(results[0].document);
  }
  return null;
}

async function registerReference(
  env: Env,
  token: string,
  mediaId: string,
  userId: string,
  ownerType: string
) {
  const referenceId = "ref_" + Math.random().toString(36).substring(2, 15);
  const body = {
    fields: {
      referenceId: { stringValue: referenceId },
      mediaId: { stringValue: mediaId },
      ownerId: { stringValue: userId },
      sourceType: { stringValue: ownerType },
      sourceDocumentId: { stringValue: "upload_registration" },
      createdAt: { timestampValue: new Date().toISOString() },
    },
  };
  await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media_references?documentId=${referenceId}`, token, body);

  // Since REST PATCH API doesn't do direct increment easily, in production, we do this via
  // a Transaction (commit REST API) using a transform with fieldTransforms increment.
  const transactionBody = {
    writes: [
      {
        transform: {
          document: `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media/${mediaId}`,
          fieldTransforms: [
            {
              fieldPath: "referenceCount",
              increment: { integerValue: "1" },
            },
          ],
        },
      },
    ],
  };
  await firestoreRequest("POST", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:commit`, token, transactionBody);
}

async function getMediaDoc(env: Env, token: string, mediaId: string): Promise<any> {
  try {
    const doc = await firestoreRequest("GET", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media/${mediaId}`, token);
    return parseFirestoreDocument(doc);
  } catch (e) {
    return null;
  }
}

async function markMediaFailed(
  env: Env,
  token: string,
  mediaId: string,
  jobId: string,
  reason: string
) {
  const mediaPatch = {
    fields: {
      status: { stringValue: "failed" },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };
  await firestoreRequest("PATCH", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/media/${mediaId}?updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt`, token, mediaPatch);

  const jobPatch = {
    fields: {
      status: { stringValue: "failed" },
      summary: {
        mapValue: {
          fields: {
            failureReason: { stringValue: reason },
            completedAt: { timestampValue: new Date().toISOString() },
          },
        },
      },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };
  await firestoreRequest("PATCH", `${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/processing_jobs/${jobId}?updateMask.fieldPaths=status&updateMask.fieldPaths=summary.failureReason&updateMask.fieldPaths=summary.completedAt&updateMask.fieldPaths=updatedAt`, token, jobPatch);
}

// --- Serializers for Firestore REST ---

function parseFirestoreDocument(doc: any): any {
  if (!doc.fields) return doc;
  const result: any = {};
  for (const key of Object.keys(doc.fields)) {
    const valObj = doc.fields[key];
    if (valObj.stringValue !== undefined) result[key] = valObj.stringValue;
    else if (valObj.integerValue !== undefined) result[key] = parseInt(valObj.integerValue, 10);
    else if (valObj.booleanValue !== undefined) result[key] = valObj.booleanValue;
    else if (valObj.mapValue !== undefined) result[key] = parseFirestoreDocument(valObj.mapValue);
    else result[key] = valObj;
  }
  return result;
}

function convertToFirestoreFields(data: any): any {
  const fields: any = {};
  for (const key of Object.keys(data)) {
    const val = data[key];
    if (typeof val === "string") fields[key] = { stringValue: val };
    else if (typeof val === "number") fields[key] = { integerValue: String(val) };
    else if (typeof val === "boolean") fields[key] = { booleanValue: val };
    else if (typeof val === "object") fields[key] = { mapValue: { fields: convertToFirestoreFields(val) } };
  }
  return fields;
}

function jsonResponse(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

async function handleGetTempMedia(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const pathParts = url.pathname.split("/");
  const filename = pathParts[pathParts.length - 1];

  const object = await env.R2_BUCKET.get(`temp/${filename}`);
  if (!object) {
    return new Response("Temp media not found", { status: 404 });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { headers });
}

async function handleAdminUpload(request: Request, env: Env, filename: string): Promise<Response> {
  const bytes = await request.arrayBuffer();
  const contentType = request.headers.get("Content-Type") || "application/octet-stream";

  await env.R2_BUCKET.put(`media/${filename}`, bytes, {
    httpMetadata: { contentType },
  });

  return jsonResponse({ status: "success", filename });
}

async function handleAdminDeleteTemp(request: Request, env: Env, filename: string): Promise<Response> {
  await env.R2_BUCKET.delete(`temp/${filename}`);
  return jsonResponse({ status: "success", message: `Temp file ${filename} deleted` });
}

async function handleAdminDeleteMedia(request: Request, env: Env, filename: string): Promise<Response> {
  await env.R2_BUCKET.delete(`media/${filename}`);
  return jsonResponse({ status: "success", message: `Media file ${filename} deleted` });
}

async function handleCancelUpload(request: Request, env: Env, user: any): Promise<Response> {
  const body = await request.json() as any;
  const mediaId = body.mediaId;
  if (!mediaId) {
    return jsonResponse({ error: "Missing mediaId" }, 400);
  }

  await env.R2_BUCKET.delete(`temp/${mediaId}_temp.mp4`);
  await env.R2_BUCKET.delete(`temp/${mediaId}_temp.webp`);

  return jsonResponse({ status: "success", message: `Canceled upload for ${mediaId}` });
}

async function handleCheckDeduplication(
  request: Request,
  env: Env,
  user: any,
  hash: string,
  token: string
): Promise<Response> {
  if (!hash) {
    return jsonResponse({ error: "Missing hash" }, 400);
  }

  const existingMedia = await findMediaByHash(env, token, hash);
  if (existingMedia && existingMedia.status === "ready") {
    const ownerType = request.headers.get("X-Owner-Type") || "post";
    await registerReference(env, token, existingMedia.mediaId, user.uid, ownerType);
    return jsonResponse({ exists: true, media: existingMedia });
  }

  return jsonResponse({ exists: false });
}
