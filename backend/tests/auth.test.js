const request = require('supertest');
const express = require('express');

const createApp = require('../src/app');
const { errorHandler } = require('../src/middleware/error');
const User = require('../src/models/User');
const { protect, authorize } = require('../src/middleware/auth');
const { ROLES } = require('../src/utils/roles');

const app = createApp();

const validUser = { name: 'Asha Rao', email: 'Asha@Example.com', password: 'Secret@123' };

async function registerAndLogin(user = validUser) {
  const res = await request(app).post('/api/auth/register').send(user);
  return res.body.data.token;
}

describe('GET /api/health', () => {
  it('returns ok', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('POST /api/auth/register', () => {
  it('creates an employee, hashes the password and returns a token', async () => {
    const res = await request(app).post('/api/auth/register').send(validUser);

    expect(res.status).toBe(201);
    expect(res.body.data.token).toEqual(expect.any(String));
    expect(res.body.data.user).toMatchObject({
      name: 'Asha Rao',
      email: 'asha@example.com',
      role: 'employee',
    });
    expect(res.body.data.user.password).toBeUndefined();
    expect(res.body.data.user.tokenVersion).toBeUndefined();

    const stored = await User.findOne({ email: 'asha@example.com' }).select('+password');
    expect(stored.password).not.toBe(validUser.password);
    expect(stored.password).toMatch(/^\$2[aby]\$/); // bcrypt hash
  });

  it('ignores a role sent in the body (no self-promotion to admin)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...validUser, role: 'admin' });
    expect(res.status).toBe(201);
    expect(res.body.data.user.role).toBe('employee');
  });

  it('rejects a duplicate email with 409', async () => {
    await request(app).post('/api/auth/register').send(validUser);
    const res = await request(app).post('/api/auth/register').send(validUser);
    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
  });

  it('validates input with field-level details', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: '', email: 'not-an-email', password: 'short' });
    expect(res.status).toBe(400);
    const fields = res.body.details.map((d) => d.field);
    expect(fields).toEqual(expect.arrayContaining(['name', 'email', 'password']));
  });
});

describe('POST /api/auth/login', () => {
  beforeEach(async () => {
    await request(app).post('/api/auth/register').send(validUser);
  });

  it('logs in with correct credentials (email is case-insensitive)', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'ASHA@example.com', password: validUser.password });
    expect(res.status).toBe(200);
    expect(res.body.data.token).toEqual(expect.any(String));
  });

  it('rejects a wrong password with a generic message', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: validUser.email, password: 'wrongpass1' });
    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('rejects an unknown email with the same message', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@example.com', password: 'whatever1' });
    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('blocks deactivated accounts', async () => {
    await User.updateOne({ email: 'asha@example.com' }, { isActive: false });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: validUser.email, password: validUser.password });
    expect(res.status).toBe(403);
  });
});

describe('Protected routes (/api/auth/me, /api/auth/logout)', () => {
  it('rejects requests without a token', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  it('rejects an invalid token', async () => {
    const res = await request(app).get('/api/auth/me').set('Authorization', 'Bearer abc.def.ghi');
    expect(res.status).toBe(401);
  });

  it('returns the current user with a valid token', async () => {
    const token = await registerAndLogin();
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.user.email).toBe('asha@example.com');
  });

  it('logout revokes the token', async () => {
    const token = await registerAndLogin();
    const auth = { Authorization: `Bearer ${token}` };

    const out = await request(app).post('/api/auth/logout').set(auth);
    expect(out.status).toBe(200);

    const res = await request(app).get('/api/auth/me').set(auth);
    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Token has been revoked');
  });
});

describe('Role-based access control (authorize middleware)', () => {
  // A throwaway app with admin-only / staff routes to exercise RBAC independently of future modules.
  const rbacApp = express();
  rbacApp.get('/test/admin-only', protect, authorize(ROLES.ADMIN), (req, res) => res.json({ ok: true }));
  rbacApp.get('/test/staff', protect, authorize(ROLES.ADMIN, ROLES.MANAGER), (req, res) =>
    res.json({ ok: true })
  );
  rbacApp.use(errorHandler);

  it('forbids an employee from an admin route', async () => {
    const token = await registerAndLogin();
    const res = await request(rbacApp).get('/test/admin-only').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  it('allows an admin', async () => {
    await User.create({ name: 'Root', email: 'admin@example.com', password: 'admin1234', role: 'admin' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@example.com', password: 'admin1234' });
    const res = await request(rbacApp)
      .get('/test/admin-only')
      .set('Authorization', `Bearer ${login.body.data.token}`);
    expect(res.status).toBe(200);
  });

  it('allows a manager on a staff route', async () => {
    await User.create({ name: 'Mgr', email: 'mgr@example.com', password: 'manager123', role: 'manager' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'mgr@example.com', password: 'manager123' });
    const res = await request(rbacApp)
      .get('/test/staff')
      .set('Authorization', `Bearer ${login.body.data.token}`);
    expect(res.status).toBe(200);
  });
});

describe('Unknown routes', () => {
  it('returns JSON 404', async () => {
    const res = await request(app).get('/api/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });
});

describe('Password rules', () => {
  const register = (password) =>
    request(app).post('/api/auth/register').send({ name: 'Pat', email: 'pat@example.com', password });
  const messageFor = async (password) => (await register(password)).body.details?.find((d) => d.field === 'password')?.message;

  it.each([
    ['Ab@1', '8-128 characters'],
    ['lower@123', 'uppercase'],
    ['UPPER@123', 'lowercase'],
    ['NoDigits@here', 'number'],
    ['NoSymbol123', 'special character'],
  ])('rejects %s (%s)', async (password, expected) => {
    expect(await messageFor(password)).toContain(expected);
  });

  it('accepts any special characters, including spaces and unicode', async () => {
    expect((await register('My pass#1 ünïcødé')).status).toBe(201);
  });
});
