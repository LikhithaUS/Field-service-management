const ApiError = require('../utils/ApiError');
const { config } = require('../config/env');

function notFound(req, res, next) {
  next(ApiError.notFound(`Route not found: ${req.method} ${req.originalUrl}`));
}

// Central error handler: every error ends up here and becomes a consistent JSON shape:
// { success: false, message, details? }
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal server error';
  let { details } = err;

  // Mongoose: duplicate unique key (e.g. email already registered)
  if (err.code === 11000) {
    statusCode = 409;
    const field = Object.keys(err.keyValue || {})[0] || 'field';
    message = `${field} already exists`;
  }
  // Mongoose: schema validation
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
    details = Object.values(err.errors).map((e) => ({ field: e.path, message: e.message }));
  }
  // Mongoose: malformed ObjectId
  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ${err.path}`;
  }
  // Malformed JSON body
  if (err.type === 'entity.parse.failed') {
    statusCode = 400;
    message = 'Invalid JSON body';
  }

  if (statusCode >= 500) {
    console.error(err);
    if (config.isProduction) message = 'Internal server error';
  }

  res.status(statusCode).json({
    success: false,
    message,
    ...(details && { details }),
  });
}

module.exports = { notFound, errorHandler };
