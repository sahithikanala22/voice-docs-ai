const crypto = require("crypto");

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 1 minute between sends
const MAX_ATTEMPTS = 5;
const E164_PATTERN = /^\+[1-9]\d{7,14}$/;

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function isValidPhoneNumber(phoneNumber) {
  return typeof phoneNumber === "string" && E164_PATTERN.test(phoneNumber);
}

module.exports = {OTP_TTL_MS, RESEND_COOLDOWN_MS, MAX_ATTEMPTS, hashCode, isValidPhoneNumber};
