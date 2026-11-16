const { app, request, loginAs, outbox } = require('./helpers');
const Attendance = require('../src/models/Attendance');
const Leave = require('../src/models/Leave');
const { clock } = require('../src/utils/time');
const { workingDays } = require('../src/controllers/leave.controller');

// "Today" is Monday 16 Nov 2026, 10:00 in India (the default company time zone).
beforeEach(() => jest.spyOn(clock, 'now').mockReturnValue(new Date('2026-11-16T10:00:00+05:30')));
afterEach(() => jest.restoreAllMocks());

const leaveBody = (overrides = {}) => ({
  leaveType: 'casual',
  startDate: '2026-11-19', // Thu
  endDate: '2026-11-23', // Mon -> Thu, Fri, Mon = 3 working days
  reason: 'Family function',
  ...overrides,
});

async function apply(auth, overrides) {
  return request(app).post('/api/leaves').set(auth).send(leaveBody(overrides));
}

describe('workingDays', () => {
  it('skips weekends', () => {
    const days = workingDays(new Date('2026-11-19T00:00:00Z'), new Date('2026-11-23T00:00:00Z'));
    expect(days.map((d) => d.toISOString().slice(0, 10))).toEqual(['2026-11-19', '2026-11-20', '2026-11-23']);
  });
});

describe('POST /api/leaves', () => {
  it('applies for leave and counts working days', async () => {
    const emp = await loginAs('employee');
    const res = await apply(emp.auth);

    expect(res.status).toBe(201);
    expect(res.body.data.leave).toMatchObject({
      leaveType: 'casual',
      status: 'pending',
      days: 3,
      startDate: '2026-11-19T00:00:00.000Z',
      endDate: '2026-11-23T00:00:00.000Z',
      user: { id: emp.user.id },
      reviewedBy: null,
    });
  });

  it('validates fields and date order', async () => {
    const emp = await loginAs('employee');
    const bad = await request(app).post('/api/leaves').set(emp.auth).send({ leaveType: 'vacation', startDate: '19/11/2026' });
    expect(bad.status).toBe(400);
    expect(bad.body.details.map((d) => d.field)).toEqual(expect.arrayContaining(['leaveType', 'startDate', 'endDate', 'reason']));

    const reversed = await apply(emp.auth, { startDate: '2026-11-25', endDate: '2026-11-20' });
    expect(reversed.status).toBe(400);
  });

  it('rejects weekend-only ranges and past dates (except sick leave)', async () => {
    const emp = await loginAs('employee');

    const weekend = await apply(emp.auth, { startDate: '2026-11-21', endDate: '2026-11-22' });
    expect(weekend.status).toBe(400);
    expect(weekend.body.message).toMatch(/no working days/);

    const past = await apply(emp.auth, { startDate: '2026-11-13', endDate: '2026-11-13' });
    expect(past.status).toBe(400);

    const sick = await apply(emp.auth, { leaveType: 'sick', startDate: '2026-11-13', endDate: '2026-11-13' });
    expect(sick.status).toBe(201);
  });

  it('rejects overlapping requests but allows after cancelling', async () => {
    const emp = await loginAs('employee');
    const first = await apply(emp.auth);

    const overlap = await apply(emp.auth, { startDate: '2026-11-23', endDate: '2026-11-24' });
    expect(overlap.status).toBe(409);

    await request(app).put(`/api/leaves/${first.body.data.leave.id}/cancel`).set(emp.auth);
    expect((await apply(emp.auth, { startDate: '2026-11-23', endDate: '2026-11-24' })).status).toBe(201);
  });
});

describe('GET /api/leaves', () => {
  it('employees see only their own; staff see all and can filter', async () => {
    const manager = await loginAs('manager');
    const a = await loginAs('employee');
    const b = await loginAs('employee');
    await apply(a.auth);
    await apply(b.auth, { leaveType: 'sick' });
    await apply(manager.auth, { startDate: '2026-12-01', endDate: '2026-12-01' });

    const own = await request(app).get(`/api/leaves?user=${b.user.id}`).set(a.auth);
    expect(own.body.data.items).toHaveLength(1);
    expect(own.body.data.items[0].user.id).toBe(a.user.id);

    const get = (qs) => request(app).get(`/api/leaves?${qs}`).set(manager.auth);
    expect((await get('')).body.data.pagination.total).toBe(3);
    expect((await get('leaveType=sick')).body.data.items[0].user.id).toBe(b.user.id);
    expect((await get('mine=true')).body.data.items).toHaveLength(1);
    expect((await get(`user=${a.user.id}&status=pending`)).body.data.pagination.total).toBe(1);
  });

  it('hides other people’s requests on the detail route', async () => {
    const a = await loginAs('employee');
    const b = await loginAs('employee');
    const { id } = (await apply(a.auth)).body.data.leave;
    expect((await request(app).get(`/api/leaves/${id}`).set(a.auth)).status).toBe(200);
    expect((await request(app).get(`/api/leaves/${id}`).set(b.auth)).status).toBe(404);
  });
});

describe('approve / reject', () => {
  it('approving marks working days as leave in attendance and emails the employee', async () => {
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');
    const { id } = (await apply(emp.auth)).body.data.leave;

    const res = await request(app).put(`/api/leaves/${id}/approve`).set(manager.auth).send({ note: 'Enjoy!' });
    expect(res.status).toBe(200);
    expect(res.body.data.leave).toMatchObject({ status: 'approved', reviewNote: 'Enjoy!', reviewedBy: { id: manager.user.id } });

    const days = await Attendance.find({ user: emp.user._id }).sort({ date: 1 });
    expect(days.map((d) => [d.date.toISOString().slice(0, 10), d.status])).toEqual([
      ['2026-11-19', 'leave'],
      ['2026-11-20', 'leave'],
      ['2026-11-23', 'leave'],
    ]);

    const mail = outbox.find((m) => m.to === emp.user.email);
    expect(mail.subject).toMatch(/approved/);
    expect(mail.text).toMatch(/3 working days/);
    expect(mail.text).toMatch(/Enjoy!/);
  });

  it('does not overwrite a day the person actually worked', async () => {
    const admin = await loginAs('admin');
    const emp = await loginAs('employee');
    await Attendance.create({ user: emp.user._id, date: new Date('2026-11-13T00:00:00Z'), checkIn: new Date(), status: 'present' });
    const { id } = (await apply(emp.auth, { leaveType: 'sick', startDate: '2026-11-12', endDate: '2026-11-13' })).body.data.leave;

    await request(app).put(`/api/leaves/${id}/approve`).set(admin.auth);
    const days = await Attendance.find({ user: emp.user._id }).sort({ date: 1 });
    expect(days.map((d) => d.status)).toEqual(['leave', 'present']);
  });

  it('rejecting records the reviewer and leaves attendance alone', async () => {
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');
    const { id } = (await apply(emp.auth)).body.data.leave;

    const res = await request(app).put(`/api/leaves/${id}/reject`).set(manager.auth).send({ note: 'Project deadline' });
    expect(res.body.data.leave.status).toBe('rejected');
    expect(await Attendance.countDocuments()).toBe(0);
    expect(outbox.find((m) => m.to === emp.user.email).subject).toMatch(/rejected/);

    // Already decided.
    expect((await request(app).put(`/api/leaves/${id}/approve`).set(manager.auth)).status).toBe(409);
  });

  it('enforces who may review', async () => {
    const admin = await loginAs('admin');
    const manager = await loginAs('manager');
    const otherManager = await loginAs('manager');
    const emp = await loginAs('employee');

    const empLeave = (await apply(emp.auth)).body.data.leave.id;
    const mgrLeave = (await apply(manager.auth)).body.data.leave.id;
    const put = (auth, id, action) => request(app).put(`/api/leaves/${id}/${action}`).set(auth);

    expect((await put(emp.auth, empLeave, 'approve')).status).toBe(403); // employees can't review
    expect((await put(manager.auth, mgrLeave, 'approve')).status).toBe(403); // not your own
    expect((await put(otherManager.auth, mgrLeave, 'approve')).status).toBe(403); // managers review employees only
    expect((await put(admin.auth, mgrLeave, 'approve')).status).toBe(200); // admins review managers
  });
});

describe('PUT /api/leaves/:id/cancel', () => {
  it('cancelling approved future leave removes it from attendance', async () => {
    const admin = await loginAs('admin');
    const emp = await loginAs('employee');
    const { id } = (await apply(emp.auth)).body.data.leave;
    await request(app).put(`/api/leaves/${id}/approve`).set(admin.auth);

    const res = await request(app).put(`/api/leaves/${id}/cancel`).set(emp.auth);
    expect(res.status).toBe(200);
    expect(res.body.data.leave.status).toBe('cancelled');
    expect(await Attendance.countDocuments({ status: 'leave' })).toBe(0);
  });

  it('only the requester can cancel, and not once the leave has started', async () => {
    const admin = await loginAs('admin');
    const emp = await loginAs('employee');
    const { id } = (await apply(emp.auth, { leaveType: 'sick', startDate: '2026-11-16', endDate: '2026-11-17' })).body.data.leave;

    expect((await request(app).put(`/api/leaves/${id}/cancel`).set(admin.auth)).status).toBe(403);

    await request(app).put(`/api/leaves/${id}/approve`).set(admin.auth);
    const started = await request(app).put(`/api/leaves/${id}/cancel`).set(emp.auth);
    expect(started.status).toBe(409);
    expect(started.body.message).toMatch(/already started/);
    expect((await Leave.findById(id)).status).toBe('approved');
  });
});
