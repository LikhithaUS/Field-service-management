const { app, request, loginAs } = require('./helpers');
const Announcement = require('../src/models/Announcement');
const Notification = require('../src/models/Notification');

const post = (auth, body = {}) =>
  request(app)
    .post('/api/announcements')
    .set(auth)
    .send({ title: 'Office closed Friday', message: 'Happy Diwali! The office is closed on Friday.', category: 'holiday', ...body });

describe('Announcements API', () => {
  it('staff post; everyone active is notified except the author', async () => {
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');
    const inactive = await loginAs('employee');
    await inactive.user.updateOne({ isActive: false });

    const res = await post(manager.auth);
    expect(res.status).toBe(201);
    expect(res.body.data.announcement).toMatchObject({
      title: 'Office closed Friday',
      category: 'holiday',
      pinned: false,
      author: { id: manager.user.id, name: manager.user.name },
    });

    const notes = await Notification.find();
    expect(notes.map((n) => n.user.toString())).toEqual([emp.user.id]);
    expect(notes[0]).toMatchObject({ type: 'announcement', entityType: 'announcement', title: 'Announcement: Office closed Friday' });
    expect(notes[0].entityId.toString()).toBe(res.body.data.announcement.id);
  });

  it('a very long title still notifies (shortened to fit)', async () => {
    const admin = await loginAs('admin');
    const emp = await loginAs('employee');
    await post(admin.auth, { title: 'A'.repeat(150) });
    const [n] = await Notification.find({ user: emp.user._id });
    expect(n.title.length).toBe(120);
    expect(n.title.endsWith('…')).toBe(true);
  });

  it('employees can read but not post', async () => {
    const admin = await loginAs('admin');
    const emp = await loginAs('employee');
    const { id } = (await post(admin.auth)).body.data.announcement;

    expect((await post(emp.auth)).status).toBe(403);
    expect((await request(app).get('/api/announcements').set(emp.auth)).body.data.items).toHaveLength(1);
    expect((await request(app).get(`/api/announcements/${id}`).set(emp.auth)).body.data.announcement.id).toBe(id);
  });

  it('lists pinned first, then newest; filters by category and search', async () => {
    const { auth } = await loginAs('admin');
    await post(auth, { title: 'Old news', category: 'general' });
    await post(auth, { title: 'Pinned rule', category: 'important', pinned: true });
    await post(auth, { title: 'Server maintenance', category: 'maintenance', message: 'Downtime Sunday night' });

    const titles = async (qs = '') =>
      (await request(app).get(`/api/announcements?${qs}`).set(auth)).body.data.items.map((a) => a.title);

    expect(await titles()).toEqual(['Pinned rule', 'Server maintenance', 'Old news']);
    expect(await titles('category=maintenance')).toEqual(['Server maintenance']);
    expect(await titles('search=downtime')).toEqual(['Server maintenance']);
  });

  it('validates input', async () => {
    const { auth } = await loginAs('admin');
    const res = await request(app).post('/api/announcements').set(auth).send({ category: 'party', pinned: 'yes' });
    expect(res.status).toBe(400);
    expect(res.body.details.map((d) => d.field)).toEqual(expect.arrayContaining(['title', 'message', 'category', 'pinned']));
  });

  it('managers edit/delete only their own; admins any; edits do not re-notify', async () => {
    const admin = await loginAs('admin');
    const manager = await loginAs('manager');
    const otherManager = await loginAs('manager');
    const { id } = (await post(manager.auth)).body.data.announcement;
    const before = await Notification.countDocuments();

    const put = (auth, body) => request(app).put(`/api/announcements/${id}`).set(auth).send(body);
    expect((await put(otherManager.auth, { pinned: true })).status).toBe(403);
    const own = await put(manager.auth, { pinned: true, title: 'Office closed Friday & Monday' });
    expect(own.body.data.announcement).toMatchObject({ pinned: true, title: 'Office closed Friday & Monday' });
    expect((await put(admin.auth, { category: 'important' })).status).toBe(200);
    expect(await Notification.countDocuments()).toBe(before);

    expect((await request(app).delete(`/api/announcements/${id}`).set(otherManager.auth)).status).toBe(403);
  });

  it('deleting removes the announcement and its notifications', async () => {
    const admin = await loginAs('admin');
    await loginAs('employee');
    const { id } = (await post(admin.auth)).body.data.announcement;
    expect(await Notification.countDocuments()).toBe(1);

    const res = await request(app).delete(`/api/announcements/${id}`).set(admin.auth);
    expect(res.status).toBe(200);
    expect(await Announcement.countDocuments()).toBe(0);
    expect(await Notification.countDocuments()).toBe(0);
    expect((await request(app).get(`/api/announcements/${id}`).set(admin.auth)).status).toBe(404);
  });
});
