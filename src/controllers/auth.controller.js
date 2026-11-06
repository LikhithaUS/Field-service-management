const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { ROLES } = require('../utils/roles');
const { signAccessToken } = require('../services/token.service');

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

module.exports = { register, login, logout, me };
