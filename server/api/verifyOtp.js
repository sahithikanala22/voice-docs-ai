const admin = require("../lib/firebaseAdmin");
const {applyCors} = require("../lib/cors");
const {MAX_ATTEMPTS, hashCode, isValidPhoneNumber} = require("../lib/otp");

module.exports = async (req, res) => {
  if (applyCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  const {phoneNumber, code} = req.body || {};
  if (!isValidPhoneNumber(phoneNumber)) {
    res.status(400).json({error: "Enter a phone number in international format, e.g. +14155551234."});
    return;
  }
  if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
    res.status(400).json({error: "Enter the 6-digit code."});
    return;
  }

  const db = admin.firestore();
  const docRef = db.collection("otpCodes").doc(phoneNumber);

  try {
    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(404).json({error: "No code was requested for this number. Request a new one."});
      return;
    }

    const data = snap.data();
    if (data.expiresAt.toMillis() < Date.now()) {
      await docRef.delete();
      res.status(410).json({error: "That code expired. Request a new one."});
      return;
    }
    if (data.attempts >= MAX_ATTEMPTS) {
      await docRef.delete();
      res.status(429).json({error: "Too many incorrect attempts. Request a new code."});
      return;
    }

    if (hashCode(code) !== data.codeHash) {
      await docRef.update({attempts: admin.firestore.FieldValue.increment(1)});
      res.status(400).json({error: "Incorrect code. Try again."});
      return;
    }

    await docRef.delete();

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      userRecord = await admin.auth().createUser({phoneNumber});
    }

    const token = await admin.auth().createCustomToken(userRecord.uid);
    res.status(200).json({token});
  } catch (error) {
    console.error("verifyOtp failed", error);
    res.status(500).json({error: "Something went wrong verifying the code."});
  }
};
