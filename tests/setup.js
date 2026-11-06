// Runs before each test file: spins up an in-memory MongoDB so tests never touch
// your real (Atlas) database, and injects test-only secrets.
require('dotenv').config(); // picks up optional MONGOMS_SYSTEM_BINARY from .env
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
process.env.BCRYPT_SALT_ROUNDS = '4'; // fast hashing in tests

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
});

afterEach(async () => {
  const { collections } = mongoose.connection;
  await Promise.all(Object.values(collections).map((c) => c.deleteMany({})));
});

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});
