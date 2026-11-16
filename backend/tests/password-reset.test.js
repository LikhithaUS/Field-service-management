const { app, request, lastCodeFor, outbox } = require('./helpers');
const User = require('../src/models/User');

const email = 'ravi@example.com';
const oldPassword = 'OldPass@123';

async function registerRavi() {
  const res = await request(app).post('/api/auth/register').send({ name: 'Ravi', email, password: oldPassword });
  return res.body.data.token;
}

describe('POST /api/auth/forgot-password', () => {
  it('emails a 6-digit code and stores only its hash', async () => {
    await registerRavi();
    const res = await request(app).post('/api/auth/forgot-password').send({ email });

    expect(res.status).toBe(200);
    const code = lastCodeFor(email);
    expect(code).toMatch(/^\d{6}$/);

    const user = await User.findOne({ email }).select('+resetCodeHash +resetCodeExpiresAt');
    expect(user.resetCodeHash).toBeDefined();
    expect(user.resetCodeHash).not.toContain(code);
    expect(user.resetCodeExpiresAt.getTime()).toBeGreaterThan(Date.now());
  });

  it('gives the same response for unknown emails and sends nothing', async () => {
    const res = await request(app).post('/api/auth/forgot-password').send({ email: 'ghost@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/If an account exists/);
    expect(outbox).toHaveLength(0);
  });

  it('never leaks reset fields in API responses', async () => {
    const token = await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.data.user.resetCodeHash).toBeUndefined();
    expect(me.body.data.user.resetCodeAttempts).toBeUndefined();
  });
});

describe('POST /api/auth/reset-password', () => {
  it('resets the password, logs the user in and revokes old sessions', async () => {
    const oldToken = await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const code = lastCodeFor(email);

    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email, code, password: 'NewPass@456' });
    expect(res.status).toBe(200);
    expect(res.body.data.token).toEqual(expect.any(String));

    // Old password no longer works, new one does.
    const oldLogin = await request(app).post('/api/auth/login').send({ email, password: oldPassword });
    expect(oldLogin.status).toBe(401);
    const newLogin = await request(app).post('/api/auth/login').send({ email, password: 'NewPass@456' });
    expect(newLogin.status).toBe(200);

    // Sessions from before the reset are revoked.
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${oldToken}`);
    expect(me.status).toBe(401);
  });

  it('a code can only be used once', async () => {
    await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const code = lastCodeFor(email);

    await request(app).post('/api/auth/reset-password').send({ email, code, password: 'NewPass@456' });
    const again = await request(app).post('/api/auth/reset-password').send({ email, code, password: 'Other@789x' });
    expect(again.status).toBe(400);
  });

  it('rejects a wrong code', async () => {
    await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const code = lastCodeFor(email);
    const wrong = code === '000000' ? '111111' : '000000';

    const res = await request(app).post('/api/auth/reset-password').send({ email, code: wrong, password: 'NewPass@456' });
    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Invalid or expired code');
  });

  it('locks the code after 5 wrong attempts, even if the right code is sent next', async () => {
    await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const code = lastCodeFor(email);
    const wrong = code === '000000' ? '111111' : '000000';

    for (let i = 0; i < 5; i += 1) {
      await request(app).post('/api/auth/reset-password').send({ email, code: wrong, password: 'NewPass@456' });
    }
    const res = await request(app).post('/api/auth/reset-password').send({ email, code, password: 'NewPass@456' });
    expect(res.status).toBe(400);
  });

  it('rejects an expired code', async () => {
    await registerRavi();
    await request(app).post('/api/auth/forgot-password').send({ email });
    const code = lastCodeFor(email);
    await User.updateOne({ email }, { resetCodeExpiresAt: new Date(Date.now() - 1000) });

    const res = await request(app).post('/api/auth/reset-password').send({ email, code, password: 'NewPass@456' });
    expect(res.status).toBe(400);
  });

  it('validates code format and password strength', async () => {
    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email, code: '12ab', password: 'short' });
    expect(res.status).toBe(400);
    const fields = res.body.details.map((d) => d.field);
    expect(fields).toEqual(expect.arrayContaining(['code', 'password']));
  });
});
