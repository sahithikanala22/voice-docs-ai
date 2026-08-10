const crypto = require("crypto");
const twilio = require("twilio");
const admin = require("../lib/firebaseAdmin");
const {applyCors} = require("../lib/cors");
const {OTP_TTL_MS, RESEND_COOLDOWN_MS, hashCode, isValidPhoneNumber} = require("../lib/otp");

module.exports = async (req, res) => {
  if (applyCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  const {phoneNumber} = req.body || {};
  if (!isValidPhoneNumber(phoneNumber)) {
    res.status(400).json({error: "Enter a phone number in international format, e.g. +14155551234."});
    return;
  }

  const db = admin.firestore();
  const docRef = db.collection("otpCodes").doc(phoneNumber);

  try {
    const existing = await docRef.get();
    if (existing.exists) {
      const createdAtMs = existing.data().createdAt?.toMillis?.() ?? 0;
      if (Date.now() - createdAtMs < RESEND_COOLDOWN_MS) {
        res.status(429).json({error: "Please wait a minute before requesting another code."});
        return;
      }
    }

    const code = crypto.randomInt(100000, 999999).toString();
    await docRef.set({
      codeHash: hashCode(code),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS),
      attempts: 0,
      createdAt: admin.firestore.Timestamp.now(),
    });

    const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    await client.messages.create({
      from: process.env.TWILIO_WHATSAPP_FROM,
      to: `whatsapp:${phoneNumber}`,
      body: `Your Voice Docs AI verification code is ${code}. It expires in 5 minutes.`,
    });

    res.status(200).json({success: true});
  } catch (error) {
    console.error("sendOtp failed", error);
    res.status(500).json({error: "Could not send the code. Try again."});
  }
};
