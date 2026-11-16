const { app, request, loginAs } = require('./helpers');
const Notification = require('../src/models/Notification');
const { notify } = require('../src/services/notification.service');
const { clock } = require('../src/utils/time');

const mine = (user) => Notification.find({ user: user._id }).sort({ createdAt: 1 });

describe('notification service', () => {
  it('skips the actor, duplicates and empty ids', async () => {
    const a = await loginAs('employee');
    const b = await loginAs('employee');
    await notify([a.user._id, a.user.id, b.user._id, null], { actor: b.user, title: 'Hi' });
    expect(await Notification.countDocuments()).toBe(1);
    expect((await mine(a.user))[0].title).toBe('Hi');
  });
});

describe('Notifications API', () => {
  async function seed() {
    const me = await loginAs('employee');
    const other = await loginAs('employee');
    await notify([me.user._id], { title: 'First' });
    await notify([me.user._id], { title: 'Second' });
    await notify([other.user._id], { title: 'Not yours' });
    return { me, other };
  }

  it('lists only my notifications, newest first, with the unread count', async () => {
    const { me } = await seed();
    const res = await request(app).get('/api/notifications').set(me.auth);
    expect(res.status).toBe(200);
    expect(res.body.data.items.map((n) => n.title)).toEqual(['Second', 'First']);
    expect(res.body.data.unreadCount).toBe(2);
    expect(res.body.data.items[0]).toMatchObject({ isRead: false, type: 'general', entityType: null });
  });

  it('marks one or all as read; unread filter and count follow', async () => {
    const { me, other } = await seed();
    const [first] = await mine(me.user);

    const read = await request(app).put(`/api/notifications/${first.id}/read`).set(me.auth);
    expect(read.body.data.notification.isRead).toBe(true);
    expect((await request(app).get('/api/notifications/unread-count').set(me.auth)).body.data.unreadCount).toBe(1);

    const unread = await request(app).get('/api/notifications?unread=true').set(me.auth);
    expect(unread.body.data.items.map((n) => n.title)).toEqual(['Second']);

    const all = await request(app).put('/api/notifications/read-all').set(me.auth);
    expect(all.body.data.updated).toBe(1);
    expect((await request(app).get('/api/notifications/unread-count').set(me.auth)).body.data.unreadCount).toBe(0);

    // Someone else's notifications are untouched.
    expect((await request(app).get('/api/notifications/unread-count').set(other.auth)).body.data.unreadCount).toBe(1);
  });

  it("can't read someone else's notification", async () => {
    const { other } = await seed();
    const [theirs] = await Notification.find({ user: other.user._id });
    const me = await loginAs('employee');
    expect((await request(app).put(`/api/notifications/${theirs.id}/read`).set(me.auth)).status).toBe(404);
  });
});

describe('triggers', () => {
  it('task assigned, reassigned, commented on and completed', async () => {
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');
    const emp2 = await loginAs('employee');

    const created = await request(app)
      .post('/api/tasks')
      .set(manager.auth)
      .send({ title: 'Fix AC', assignedTo: emp.user.id });
    const task = created.body.data.task;

    let [n] = await mine(emp.user);
    expect(n).toMatchObject({ type: 'task_assigned', title: 'New task assigned', entityType: 'task' });
    expect(n.entityId.toString()).toBe(task.id);
    expect(n.message).toContain('TSK-0001: Fix AC');

    // Reassign: only the new assignee hears about it.
    await request(app).put(`/api/tasks/${task.id}`).set(manager.auth).send({ assignedTo: emp2.user.id });
    [n] = await mine(emp2.user);
    expect(n.title).toBe('Task assigned to you');

    // Comment from the assignee notifies the manager, not the commenter.
    await request(app).post(`/api/tasks/${task.id}/comments`).set(emp2.auth).send({ message: 'On my way' });
    const managerNotes = await mine(manager.user);
    expect(managerNotes.map((x) => x.type)).toEqual(['task_comment']);
    expect(managerNotes[0].message).toBe(`${emp2.user.name}: On my way`);
    expect(await Notification.countDocuments({ user: emp2.user._id, type: 'task_comment' })).toBe(0);

    // Completion notifies whoever assigned it.
    await request(app).put(`/api/tasks/${task.id}`).set(emp2.auth).send({ status: 'completed' });
    expect((await mine(manager.user)).map((x) => x.type)).toEqual(['task_comment', 'task_completed']);
  });

  it('leave requests reach the right reviewers; decisions reach the requester', async () => {
    jest.spyOn(clock, 'now').mockReturnValue(new Date('2026-11-16T10:00:00+05:30'));
    const admin = await loginAs('admin');
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');
    const body = { leaveType: 'casual', startDate: '2026-11-19', endDate: '2026-11-19', reason: 'Errand' };

    const empLeave = (await request(app).post('/api/leaves').set(emp.auth).send(body)).body.data.leave;
    expect((await mine(admin.user)).map((n) => n.type)).toEqual(['leave_requested']);
    expect((await mine(manager.user))[0].message).toContain('requested 1 day of casual leave from 2026-11-19');

    // A manager's own request goes to admins only (managers can't review managers).
    await request(app).post('/api/leaves').set(manager.auth).send(body);
    expect(await Notification.countDocuments({ user: admin.user._id })).toBe(2);
    expect(await Notification.countDocuments({ user: manager.user._id })).toBe(1);

    await request(app).put(`/api/leaves/${empLeave.id}/approve`).set(manager.auth).send({ note: 'Fine' });
    const [decision] = await mine(emp.user);
    expect(decision).toMatchObject({ type: 'leave_decision', title: 'Leave approved', entityType: 'leave' });
    expect(decision.message).toContain('"Fine"');
    jest.restoreAllMocks();
  });
});
