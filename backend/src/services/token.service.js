const jwt = require('jsonwebtoken');
const { config } = require('../config/env');

// Payload: sub = user id, role, tv = tokenVersion (bumped on logout to revoke old tokens).
function signAccessToken(user) {
  return jwt.sign(
    { sub: user._id.toString(), role: user.role, tv: user.tokenVersion },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
}

function verifyAccessToken(token) {
  return jwt.verify(token, config.jwt.secret);
}

module.exports = { signAccessToken, verifyAccessToken };
