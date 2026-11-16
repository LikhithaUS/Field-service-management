// Creates the default departments from the project plan (skips any that already exist).
// Usage: npm run seed:departments
const { config, assertRequired } = require('../config/env');
const { connectDB, disconnectDB } = require('../config/db');
const Department = require('../models/Department');

const DEFAULTS = [
  { name: 'IT', description: 'Information technology and internal systems' },
  { name: 'HR', description: 'People, hiring and employee relations' },
  { name: 'Finance', description: 'Accounting, payroll and budgeting' },
  { name: 'Marketing', description: 'Brand, campaigns and communications' },
  { name: 'Sales', description: 'Customer acquisition and accounts' },
  { name: 'Operations', description: 'Field service and day-to-day operations' },
];

async function seed() {
  assertRequired();
  await connectDB(config.mongoUri);
  await Department.syncIndexes();

  for (const dept of DEFAULTS) {
    const exists = await Department.findOne({ name: dept.name }).collation({ locale: 'en', strength: 2 });
    if (exists) {
      console.log(`- ${dept.name} already exists`);
    } else {
      await Department.create(dept);
      console.log(`+ ${dept.name} created`);
    }
  }
  await disconnectDB();
}

seed().catch(async (err) => {
  console.error('Seeding failed:', err.message);
  await disconnectDB().catch(() => {});
  process.exit(1);
});
