const request = require('supertest');
const createApp = require('../src/app');
const User = require('../src/models/User');
const { outbox } = require('../src/services/email.service');

const app = createApp();

let counter = 0;

/** Creates a user with the given role directly in the DB and returns { user, token, auth }. */
async function loginAs(role = 'employee', overrides = {}) {
  counter += 1;
  const email = overrides.email || `${role}${counter}@example.com`;
  const password = 'password123';
  const user = await User.create({ name: `${role} ${counter}`, email, password, role, ...overrides });
  const res = await request(app).post('/api/auth/login').send({ email, password });
  const { token } = res.body.data;
  return { user, token, auth: { Authorization: `Bearer ${token}` } };
}

/** Extracts the 6-digit code from the latest email sent to `to`. */
function lastCodeFor(to) {
  const mail = [...outbox].reverse().find((m) => m.to === to);
  if (!mail) return null;
  return mail.text.match(/\b(\d{6})\b/)[1];
}

module.exports = { app, request, loginAs, lastCodeFor, outbox };
