const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { ROLES } = require('../utils/roles');
const { signAccessToken } = require('../services/token.service');
const { issueCode, checkCode, clearCode, CODE_FIELDS } = require('../services/code.service');
const { sendEmail } = require('../services/email.service');
const { passwordResetEmail } = require('../services/email.templates');

function authResponse(res, statusCode, user) {
  res.status(statusCode).json({
    success: true,
    data: { token: signAccessToken(user), user },
  });
}

// POST /api/auth/register
// Public self-registration always creates an "employee". The role is never read from the
// request body, so nobody can register themselves as admin. Admins promote users later.
async function register(req, res) {
  const { name, email, password } = req.body;

  const exists = await User.exists({ email });
  if (exists) throw ApiError.conflict('Email is already registered');

  const user = await User.create({ name, email, password, role: ROLES.EMPLOYEE });
  authResponse(res, 201, user);
}

// POST /api/auth/login
async function login(req, res) {
  const { email, password } = req.body;

  const user = await User.findOne({ email }).select('+password +tokenVersion');
  // Same message for unknown email and wrong password, so attackers can't discover accounts.
  if (!user || !(await user.comparePassword(password))) {
    throw ApiError.unauthorized('Invalid email or password');
  }
  if (!user.isActive) throw ApiError.forbidden('Account is deactivated');

  authResponse(res, 200, user);
}

// POST /api/auth/logout  (protected)
// JWTs are stateless, so we revoke them by bumping tokenVersion: every token issued
// before this point stops working, on all devices.
async function logout(req, res) {
  await User.updateOne({ _id: req.user._id }, { $inc: { tokenVersion: 1 } });
  res.json({ success: true, message: 'Logged out successfully' });
}

// GET /api/auth/me  (protected) - returns the current user; Flutter calls it on app start.
async function me(req, res) {
  res.json({ success: true, data: { user: req.user } });
}

// POST /api/auth/forgot-password  { email }
// Always answers the same way, whether or not the email exists, so this endpoint
// can't be used to discover which emails have accounts.
async function forgotPassword(req, res) {
  const user = await User.findOne({ email: req.body.email }).select(CODE_FIELDS);
  if (user && user.isActive) {
    const code = await issueCode(user, 'reset');
    await sendEmail(passwordResetEmail(user, code));
  }
  res.json({
    success: true,
    message: 'If an account exists for that email, a 6-digit reset code has been sent.',
  });
}

// POST /api/auth/reset-password  { email, code, password }
// Used both for "forgot password" and for new employees setting their first password.
// On success: password changed, code consumed, all old sessions revoked, user logged in.
async function resetPassword(req, res) {
  const { email, code, password } = req.body;
  const invalid = ApiError.badRequest('Invalid or expired code');

  const user = await User.findOne({ email }).select(`+tokenVersion ${CODE_FIELDS}`);
  if (!user || !user.isActive) throw invalid;

  const result = checkCode(user, code);
  if (result === 'invalid') {
    user.resetCodeAttempts = (user.resetCodeAttempts || 0) + 1;
    await user.save();
    throw invalid;
  }
  if (result !== 'ok') {
    // Expired or too many wrong attempts: burn the code so a new one must be requested.
    if (result !== 'none') {
      clearCode(user);
      await user.save();
    }
    throw invalid;
  }

  user.password = password; // hashed by the pre-save hook
  clearCode(user);
  user.tokenVersion += 1;
  await user.save();

  authResponse(res, 200, user);
}

module.exports = { register, login, logout, me, forgotPassword, resetPassword };
