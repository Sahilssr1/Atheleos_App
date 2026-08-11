const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "atheleos-4a146"
});

const db = admin.firestore();

async function run() {
  console.log("=== FETCHING RECENT MEDIA ===");
  const mediaSnap = await db.collection("media").orderBy("createdAt", "desc").limit(5).get();
  mediaSnap.forEach(doc => {
    console.log(`Media: ${doc.id}`);
    console.log(JSON.stringify(doc.data(), null, 2));
  });

  console.log("=== FETCHING RECENT PROCESSING JOBS ===");
  const jobsSnap = await db.collection("processing_jobs").orderBy("updatedAt", "desc").limit(5).get();
  jobsSnap.forEach(doc => {
    console.log(`Job: ${doc.id}`);
    console.log(JSON.stringify(doc.data(), null, 2));
  });
}

run().catch(console.error);
