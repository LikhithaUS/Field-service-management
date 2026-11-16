const { app, request, loginAs } = require('./helpers');
const Task = require('../src/models/Task');
const Comment = require('../src/models/Comment');

const newTask = (assignedTo, overrides = {}) => ({
  title: 'Install router at client site',
  description: 'Bring the spare cable.',
  location: 'MG Road, Bengaluru',
  assignedTo: assignedTo.id,
  priority: 'high',
  dueDate: '2026-12-01',
  ...overrides,
});

/** Admin + a field employee, with one task assigned to the employee. */
async function setup() {
  const admin = await loginAs('admin');
  const emp = await loginAs('employee');
  const res = await request(app).post('/api/tasks').set(admin.auth).send(newTask(emp.user));
  return { admin, emp, task: res.body.data.task };
}

describe('POST /api/tasks', () => {
  it('creates a task with a sequential number and populated people', async () => {
    const { admin, emp, task } = await setup();

    expect(task).toMatchObject({
      taskNumber: 'TSK-0001',
      title: 'Install router at client site',
      status: 'pending',
      priority: 'high',
      completedAt: null,
      commentCount: 0,
      assignedTo: { id: emp.user.id, name: emp.user.name },
      assignedBy: { id: admin.user.id },
    });
    expect(task.dueDate).toBe('2026-12-01T00:00:00.000Z');

    const second = await request(app).post('/api/tasks').set(admin.auth).send(newTask(emp.user));
    expect(second.body.data.task.taskNumber).toBe('TSK-0002');
  });

  it('managers can create tasks, employees cannot', async () => {
    const manager = await loginAs('manager');
    const emp = await loginAs('employee');

    const ok = await request(app).post('/api/tasks').set(manager.auth).send(newTask(emp.user));
    expect(ok.status).toBe(201);

    const denied = await request(app).post('/api/tasks').set(emp.auth).send(newTask(emp.user));
    expect(denied.status).toBe(403);
  });

  it('validates fields and rejects inactive or unknown assignees', async () => {
    const { auth } = await loginAs('admin');
    const inactive = await loginAs('employee');
    await inactive.user.updateOne({ isActive: false });

    const missing = await request(app).post('/api/tasks').set(auth).send({ priority: 'extreme' });
    expect(missing.status).toBe(400);
    const fields = missing.body.details.map((d) => d.field);
    expect(fields).toEqual(expect.arrayContaining(['title', 'assignedTo', 'priority']));

    const bad = await request(app).post('/api/tasks').set(auth).send(newTask(inactive.user));
    expect(bad.status).toBe(400);
    expect(bad.body.message).toMatch(/inactive/);
  });
});

describe('GET /api/tasks', () => {
  it('employees only see tasks assigned to them; staff see all', async () => {
    const { admin, emp } = await setup();
    const other = await loginAs('employee');
    await request(app).post('/api/tasks').set(admin.auth).send(newTask(other.user, { title: 'Other job' }));

    const mine = await request(app).get('/api/tasks').set(emp.auth);
    expect(mine.body.data.items.map((t) => t.title)).toEqual(['Install router at client site']);

    // An employee can't widen the filter to someone else's tasks.
    const sneaky = await request(app).get(`/api/tasks?assignedTo=${other.user.id}`).set(emp.auth);
    expect(sneaky.body.data.items).toHaveLength(1);
    expect(sneaky.body.data.items[0].assignedTo.id).toBe(emp.user.id);

    const all = await request(app).get('/api/tasks').set(admin.auth);
    expect(all.body.data.pagination.total).toBe(2);
  });

  it('filters by search, status, priority, assignee and mine', async () => {
    const { admin, emp } = await setup();
    await request(app)
      .post('/api/tasks')
      .set(admin.auth)
      .send(newTask(admin.user, { title: 'Audit stock', priority: 'low', status: 'in_progress' }));

    const get = (qs) => request(app).get(`/api/tasks?${qs}`).set(admin.auth);
    const titles = (res) => res.body.data.items.map((t) => t.title);

    expect(titles(await get('search=audit'))).toEqual(['Audit stock']);
    expect(titles(await get('search=TSK-0001'))).toEqual(['Install router at client site']);
    expect(titles(await get('status=in_progress'))).toEqual(['Audit stock']);
    expect(titles(await get('priority=high'))).toEqual(['Install router at client site']);
    expect(titles(await get(`assignedTo=${emp.user.id}`))).toEqual(['Install router at client site']);
    expect(titles(await get('mine=true'))).toEqual(['Audit stock']);
  });

  it('overdue returns open tasks whose due date has passed', async () => {
    const { admin, emp } = await setup(); // due 2026-12-01
    const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    await request(app).post('/api/tasks').set(admin.auth).send(newTask(emp.user, { title: 'Late', dueDate: yesterday }));
    await request(app)
      .post('/api/tasks')
      .set(admin.auth)
      .send(newTask(emp.user, { title: 'Late but done', dueDate: yesterday, status: 'completed' }));
    await request(app).post('/api/tasks').set(admin.auth).send(newTask(emp.user, { title: 'No date', dueDate: null }));

    const res = await request(app).get('/api/tasks?overdue=true').set(admin.auth);
    expect(res.body.data.items.map((t) => t.title)).toEqual(['Late']);

    const doneAndOverdue = await request(app).get('/api/tasks?overdue=true&status=completed').set(admin.auth);
    expect(doneAndOverdue.body.data.items).toHaveLength(0);
  });

  it('paginates and sorts', async () => {
    const { auth, user } = await loginAs('admin');
    for (const title of ['C', 'A', 'B']) {
      await request(app).post('/api/tasks').set(auth).send(newTask(user, { title }));
    }
    const res = await request(app).get('/api/tasks?sort=title&limit=2&page=2').set(auth);
    expect(res.body.data.items.map((t) => t.title)).toEqual(['C']);
    expect(res.body.data.pagination).toEqual({ page: 2, limit: 2, total: 3, totalPages: 2 });

    const bad = await request(app).get('/api/tasks?sort=password').set(auth);
    expect(bad.status).toBe(400);
  });
});

describe('GET /api/tasks/:id', () => {
  it('hides tasks that belong to someone else', async () => {
    const { emp, task } = await setup();
    const other = await loginAs('employee');

    const own = await request(app).get(`/api/tasks/${task.id}`).set(emp.auth);
    expect(own.status).toBe(200);
    expect(own.body.data.task.title).toBe('Install router at client site');

    const res = await request(app).get(`/api/tasks/${task.id}`).set(other.auth);
    expect(res.status).toBe(404);
  });
});

describe('PUT /api/tasks/:id', () => {
  it('assignee can move the status and completedAt follows it', async () => {
    const { emp, task } = await setup();
    const put = (body) => request(app).put(`/api/tasks/${task.id}`).set(emp.auth).send(body);

    expect((await put({ status: 'in_progress' })).body.data.task.status).toBe('in_progress');

    const done = await put({ status: 'completed' });
    expect(done.status).toBe(200);
    expect(done.body.data.task.completedAt).not.toBeNull();

    const reopened = await put({ status: 'in_progress' });
    expect(reopened.body.data.task.completedAt).toBeNull();
  });

  it('assignee cannot edit other fields, cancel, or touch a cancelled task', async () => {
    const { admin, emp, task } = await setup();
    const put = (auth, body) => request(app).put(`/api/tasks/${task.id}`).set(auth).send(body);

    expect((await put(emp.auth, { title: 'Hacked' })).status).toBe(403);
    expect((await put(emp.auth, { status: 'cancelled' })).status).toBe(403);

    await put(admin.auth, { status: 'cancelled' });
    const res = await put(emp.auth, { status: 'in_progress' });
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/cancelled/);
  });

  it('other employees cannot update the task', async () => {
    const { task } = await setup();
    const other = await loginAs('employee');
    const res = await request(app).put(`/api/tasks/${task.id}`).set(other.auth).send({ status: 'completed' });
    expect(res.status).toBe(404);
  });

  it('staff can reassign, reprioritise and clear the due date', async () => {
    const { admin, task } = await setup();
    const manager = await loginAs('manager');
    const newPerson = await loginAs('employee');

    const res = await request(app)
      .put(`/api/tasks/${task.id}`)
      .set(manager.auth)
      .send({ assignedTo: newPerson.user.id, priority: 'urgent', dueDate: null });

    expect(res.status).toBe(200);
    expect(res.body.data.task).toMatchObject({
      assignedTo: { id: newPerson.user.id },
      assignedBy: { id: admin.user.id }, // the creator doesn't change
      priority: 'urgent',
      dueDate: null,
    });
  });
});

describe('DELETE /api/tasks/:id', () => {
  it('staff delete the task and its comments; employees cannot', async () => {
    const { admin, emp, task } = await setup();
    await request(app).post(`/api/tasks/${task.id}/comments`).set(emp.auth).send({ message: 'On my way' });

    expect((await request(app).delete(`/api/tasks/${task.id}`).set(emp.auth)).status).toBe(403);

    const res = await request(app).delete(`/api/tasks/${task.id}`).set(admin.auth);
    expect(res.status).toBe(200);
    expect(await Task.countDocuments()).toBe(0);
    expect(await Comment.countDocuments()).toBe(0);
  });
});

describe('Task comments', () => {
  it('assignee and staff can post; thread is oldest first with authors', async () => {
    const { admin, emp, task } = await setup();
    const url = `/api/tasks/${task.id}/comments`;

    await request(app).post(url).set(admin.auth).send({ message: 'Please update the report.' });
    const reply = await request(app).post(url).set(emp.auth).send({ message: '  Report updated.  ' });
    expect(reply.status).toBe(201);
    expect(reply.body.data.comment).toMatchObject({ message: 'Report updated.', user: { id: emp.user.id } });

    const thread = await request(app).get(url).set(emp.auth);
    expect(thread.body.data.items.map((c) => c.message)).toEqual(['Please update the report.', 'Report updated.']);

    const detail = await request(app).get(`/api/tasks/${task.id}`).set(admin.auth);
    expect(detail.body.data.task.commentCount).toBe(2);
  });

  it('rejects empty comments and outsiders', async () => {
    const { emp, task } = await setup();
    const other = await loginAs('employee');
    const url = `/api/tasks/${task.id}/comments`;

    expect((await request(app).post(url).set(emp.auth).send({ message: '   ' })).status).toBe(400);
    expect((await request(app).post(url).set(other.auth).send({ message: 'hi' })).status).toBe(404);
    expect((await request(app).get(url).set(other.auth)).status).toBe(404);
  });
});
