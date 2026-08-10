const admin = require("firebase-admin");

// The service account JSON file downloaded from Firebase Console -> Project
// settings -> Service accounts -> Generate new private key must never be
// committed to the repo (it grants full admin access to the Firebase
// project) or deployed as a file on Vercel (deployments only contain what's
// in git). Instead, paste that file's entire contents as one Vercel
// environment variable, and parse it back into an object here.
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY || "{}");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

module.exports = admin;
