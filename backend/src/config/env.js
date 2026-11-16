// Loads and validates environment variables in one place.
// Every other module imports config from here instead of reading process.env directly.
require('dotenv').config();

const env = process.env.NODE_ENV || 'development';

const config = {
  env,
  isTest: env === 'test',
  isProduction: env === 'production',
  port: Number(process.env.PORT) || 5000,
  mongoUri: process.env.MONGODB_URI,
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '1d',
  },
  bcryptSaltRounds: Number(process.env.BCRYPT_SALT_ROUNDS) || 10,
  // Comma-separated list of allowed origins for CORS (e.g. the Flutter Web URL). "*" allows all.
  corsOrigins: (process.env.CORS_ORIGINS || '*').split(',').map((o) => o.trim()),
  attendance: {
    // The company's time zone decides which calendar day a check-in belongs to and whether it's late,
    // so results don't depend on where the server happens to run.
    timeZone: process.env.APP_TIMEZONE || 'Asia/Kolkata',
    workStart: process.env.WORK_START_TIME || '09:30', // HH:mm; checking in after this is "late"
    halfDayHours: Number(process.env.HALF_DAY_HOURS) || 4, // working less than this is a "half day"
  },
};

// Fail fast on startup if a required secret is missing (tests inject their own values).
function assertRequired() {
  const missing = [];
  if (!config.mongoUri) missing.push('MONGODB_URI');
  if (!config.jwt.secret) missing.push('JWT_SECRET');
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}. See .env.example`);
  }
}

module.exports = { config, assertRequired };
