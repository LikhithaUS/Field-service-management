const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { verifyAccessToken } = require('../services/token.service');

// Verifies "Authorization: Bearer <JWT>" and attaches the user to req.user.
// (Express 5 forwards errors thrown in async middleware to the error handler automatically.)
async function protect(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    throw ApiError.unauthorized('Missing or malformed Authorization header');
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (err) {
    throw ApiError.unauthorized(err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token');
  }

  const user = await User.findById(payload.sub).select('+tokenVersion');
  if (!user || !user.isActive) throw ApiError.unauthorized('User no longer exists or is inactive');
  if (user.tokenVersion !== payload.tv) throw ApiError.unauthorized('Token has been revoked');

  req.user = user;
  next();
}

// Role-based access control: authorize('admin', 'manager') allows only those roles.
// Must run after protect.
function authorize(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) throw ApiError.unauthorized();
    if (!allowedRoles.includes(req.user.role)) throw ApiError.forbidden();
    next();
  };
}

module.exports = { protect, authorize };
