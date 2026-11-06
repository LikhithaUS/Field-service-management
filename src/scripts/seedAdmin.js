// Creates the first admin account (public registration only creates employees).
// Usage: set ADMIN_NAME, ADMIN_EMAIL, ADMIN_PASSWORD in .env, then run: npm run seed:admin
const { config, assertRequired } = require('../config/env');
const { connectDB, disconnectDB } = require('../config/db');
const User = require('../models/User');
const { ROLES } = require('../utils/roles');

async function seed() {
  assertRequired();
  const { ADMIN_NAME = 'Admin', ADMIN_EMAIL, ADMIN_PASSWORD } = process.env;
  if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
    throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD in .env first');
  }

  await connectDB(config.mongoUri);
  const email = ADMIN_EMAIL.toLowerCase().trim();
  const existing = await User.findOne({ email });
  if (existing) {
    console.log(`User ${email} already exists (role: ${existing.role}). Nothing changed.`);
  } else {
    await User.create({ name: ADMIN_NAME, email, password: ADMIN_PASSWORD, role: ROLES.ADMIN });
    console.log(`Admin ${email} created.`);
  }
  await disconnectDB();
}

seed().catch(async (err) => {
  console.error('Seeding failed:', err.message);
  await disconnectDB().catch(() => {});
  process.exit(1);
});
