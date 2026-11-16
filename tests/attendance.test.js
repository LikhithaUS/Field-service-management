const { app, request, loginAs } = require('./helpers');
const Attendance = require('../src/models/Attendance');
const { clock, workDate } = require('../src/utils/time');

// Default rules: Asia/Kolkata (UTC+5:30), work starts 09:30, half day under 4 hours.
// Each helper freezes "now" at an IST wall-clock time.
const at = (isoIst) => jest.spyOn(clock, 'now').mockReturnValue(new Date(`${isoIst}+05:30`));

afterEach(() => jest.restoreAllMocks());

describe('time utils', () => {
  it('uses the company time zone to decide the work day', () => {
    // 20:00 UTC on the 15th is already 01:30 on the 16th in India.
    expect(workDate(new Date('2026-11-15T20:00:00Z'), 'Asia/Kolkata').toISOString()).toBe('2026-11-16T00:00:00.000Z');
    expect(workDate(new Date('2026-11-15T20:00:00Z'), 'UTC').toISOString()).toBe('2026-11-15T00:00:00.000Z');
  });
});

describe('check-in / check-out', () => {
  it('records an on-time day with working minutes', async () => {
    const { auth } = await loginAs('employee');

    at('2026-11-16T08:56:00');
    const inRes = await request(app).post('/api/attendance/check-in').set(auth);
    expect(inRes.status).toBe(201);
    expect(inRes.body.data.attendance).toMatchObject({ status: 'present', date: '2026-11-16T00:00:00.000Z', checkOut: null });

    at('2026-11-16T17:42:00');
    const outRes = await request(app).post('/api/attendance/check-out').set(auth);
    expect(outRes.status).toBe(200);
    expect(outRes.body.data.attendance).toMatchObject({ status: 'present', workingMinutes: 526 }); // 8h 46m
  });

  it('marks a check-in after the start time as late', async () => {
    const { auth } = await loginAs('employee');
    at('2026-11-16T09:31:00');
    const res = await request(app).post('/api/attendance/check-in').set(auth);
    expect(res.body.data.attendance.status).toBe('late');
  });

  it('marks a short day as half day', async () => {
    const { auth } = await loginAs('employee');
    at('2026-11-16T09:00:00');
    await request(app).post('/api/attendance/check-in').set(auth);
    at('2026-11-16T12:30:00');
    const res = await request(app).post('/api/attendance/check-out').set(auth);
    expect(res.body.data.attendance).toMatchObject({ status: 'half_day', workingMinutes: 210 });
  });

  it('rejects a second check-in, a check-out before check-in, and a second check-out', async () => {
    const { auth } = await loginAs('employee');
    at('2026-11-16T09:00:00');

    expect((await request(app).post('/api/attendance/check-out').set(auth)).status).toBe(400);
    await request(app).post('/api/attendance/check-in').set(auth);

    const again = await request(app).post('/api/attendance/check-in').set(auth);
    expect(again.status).toBe(409);
    expect(again.body.message).toMatch(/already checked in/);

    await request(app).post('/api/attendance/check-out').set(auth);
    expect((await request(app).post('/api/attendance/check-out').set(auth)).status).toBe(409);
    expect(await Attendance.countDocuments()).toBe(1);
  });

  it('a new day allows a new check-in', async () => {
    const { auth } = await loginAs('employee');
    at('2026-11-16T09:00:00');
    await request(app).post('/api/attendance/check-in').set(auth);
    at('2026-11-17T09:00:00');
    expect((await request(app).post('/api/attendance/check-in').set(auth)).status).toBe(201);
  });

  it('requires authentication', async () => {
    expect((await request(app).post('/api/attendance/check-in')).status).toBe(401);
  });
});

describe('GET /api/attendance/today', () => {
  it('returns null before check-in, then the record, plus the rules', async () => {
    const { auth } = await loginAs('employee');
    at('2026-11-16T08:00:00');

    const before = await request(app).get('/api/attendance/today').set(auth);
    expect(before.body.data).toMatchObject({
      date: '2026-11-16T00:00:00.000Z',
      attendance: null,
      rules: { timeZone: 'Asia/Kolkata', workStart: '09:30', halfDayHours: 4 },
    });

    await request(app).post('/api/attendance/check-in').set(auth);
    const after = await request(app).get('/api/attendance/today').set(auth);
    expect(after.body.data.attendance.status).toBe('present');
  });
});

describe('GET /api/attendance', () => {
  /** Creates records for two employees on three days. */
  async function seed() {
    const admin = await loginAs('admin');
    const a = await loginAs('employee');
    const b = await loginAs('employee');
    const day = (d) => new Date(`2026-11-${d}T00:00:00.000Z`);
    await Attendance.create([
      { user: a.user._id, date: day(14), status: 'present', workingMinutes: 500 },
      { user: a.user._id, date: day(15), status: 'late', workingMinutes: 450 },
      { user: a.user._id, date: day(16), status: 'half_day', workingMinutes: 200 },
      { user: b.user._id, date: day(16), status: 'present', workingMinutes: 480 },
    ]);
    return { admin, a, b };
  }

  it('employees only see their own history, newest first, with a summary', async () => {
    const { a, b } = await seed();

    const res = await request(app).get(`/api/attendance?user=${b.user.id}`).set(a.auth); // user filter ignored
    expect(res.status).toBe(200);
    expect(res.body.data.items.map((r) => r.date.slice(0, 10))).toEqual(['2026-11-16', '2026-11-15', '2026-11-14']);
    expect(res.body.data.items.every((r) => r.user.id === a.user.id)).toBe(true);
    expect(res.body.data.summary).toMatchObject({ present: 1, late: 1, half_day: 1, totalMinutes: 1150 });
  });

  it('staff see everyone and can filter by user, date range and status', async () => {
    const { admin, a } = await seed();
    const get = (qs) => request(app).get(`/api/attendance?${qs}`).set(admin.auth);

    const all = await get('');
    expect(all.body.data.pagination.total).toBe(4);
    expect(all.body.data.items[0].user).toHaveProperty('name');

    expect((await get('from=2026-11-16&to=2026-11-16')).body.data.pagination.total).toBe(2);
    expect((await get(`user=${a.user.id}&from=2026-11-15`)).body.data.summary).toMatchObject({ late: 1, half_day: 1, present: 0 });
    expect((await get('status=present')).body.data.pagination.total).toBe(2);
  });

  it('validates the query', async () => {
    const { auth } = await loginAs('admin');
    expect((await request(app).get('/api/attendance?from=16-11-2026').set(auth)).status).toBe(400);
    expect((await request(app).get('/api/attendance?from=2026-11-16&to=2026-11-01').set(auth)).status).toBe(400);
    expect((await request(app).get('/api/attendance?status=sleeping').set(auth)).status).toBe(400);
  });
});
