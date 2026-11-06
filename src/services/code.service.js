const crypto = require('crypto');
const { config } = require('../config/env');

// One-time 6-digit codes used for "forgot password" and for new employees setting
// their first password. Same mechanism, different lifetimes.
const CODE_TTL_MS = {
  reset: 15 * 60 * 1000, // 15 minutes
  setup: 72 * 60 * 60 * 1000, // 3 days for a new employee to set up their account
};
const MAX_ATTEMPTS = 5;

// Fields that must be selected (they are select:false) before calling these helpers.
const CODE_FIELDS = '+resetCodeHash +resetCodeExpiresAt +resetCodeAttempts';

// Codes are short, so a plain hash could be brute-forced offline from a DB leak.
// HMAC with the server secret prevents that.
function hashCode(code) {
  return crypto.createHmac('sha256', config.jwt.secret).update(String(code)).digest('hex');
}

/** Generates a code, stores its hash on the user (saved), and returns the plain code to email. */
async function issueCode(user, purpose = 'reset') {
  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
  user.resetCodeHash = hashCode(code);
  user.resetCodeExpiresAt = new Date(Date.now() + CODE_TTL_MS[purpose]);
  user.resetCodeAttempts = 0;
  await user.save();
  return code;
}

/** @returns {'ok'|'none'|'expired'|'locked'|'invalid'} */
function checkCode(user, code) {
  if (!user.resetCodeHash || !user.resetCodeExpiresAt) return 'none';
  if ((user.resetCodeAttempts || 0) >= MAX_ATTEMPTS) return 'locked';
  if (user.resetCodeExpiresAt.getTime() < Date.now()) return 'expired';

  const expected = Buffer.from(user.resetCodeHash, 'hex');
  const actual = Buffer.from(hashCode(code), 'hex');
  // Constant-time comparison avoids leaking how many characters matched.
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual) ? 'ok' : 'invalid';
}

function clearCode(user) {
  user.resetCodeHash = undefined;
  user.resetCodeExpiresAt = undefined;
  user.resetCodeAttempts = 0;
}

module.exports = { issueCode, checkCode, clearCode, CODE_FIELDS, MAX_ATTEMPTS, CODE_TTL_MS };
