const { app, request, loginAs } = require('./helpers');
const Department = require('../src/models/Department');
const Employee = require('../src/models/Employee');

describe('Departments API', () => {
  it('admin can create, list (with counts), update and delete', async () => {
    const { auth } = await loginAs('admin');

    const created = await request(app).post('/api/departments').set(auth).send({ name: 'IT', description: 'Tech' });
    expect(created.status).toBe(201);
    const { id } = created.body.data.department;

    await Employee.create({ employeeId: 'EMP-0001', name: 'A', email: 'a@x.com', department: id });

    const list = await request(app).get('/api/departments').set(auth);
    expect(list.status).toBe(200);
    expect(list.body.data.items).toEqual([expect.objectContaining({ id, name: 'IT', employeeCount: 1 })]);

    const updated = await request(app).put(`/api/departments/${id}`).set(auth).send({ name: 'Information Technology' });
    expect(updated.status).toBe(200);
    expect(updated.body.data.department.name).toBe('Information Technology');

    await Employee.deleteMany({});
    const del = await request(app).delete(`/api/departments/${id}`).set(auth);
    expect(del.status).toBe(200);
    expect(await Department.countDocuments()).toBe(0);
  });

  it('rejects duplicate names regardless of case', async () => {
    const { auth } = await loginAs('admin');
    await request(app).post('/api/departments').set(auth).send({ name: 'Sales' });
    const dup = await request(app).post('/api/departments').set(auth).send({ name: 'sales' });
    expect(dup.status).toBe(409);
  });

  it('refuses to delete a department that still has employees', async () => {
    const { auth } = await loginAs('admin');
    const dept = await Department.create({ name: 'HR' });
    await Employee.create({ employeeId: 'EMP-0001', name: 'A', email: 'a@x.com', department: dept._id });

    const res = await request(app).delete(`/api/departments/${dept.id}`).set(auth);
    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/Reassign/);
  });

  it('managers and employees can read but not modify', async () => {
    const dept = await Department.create({ name: 'Ops' });
    for (const role of ['manager', 'employee']) {
      const { auth } = await loginAs(role);
      expect((await request(app).get('/api/departments').set(auth)).status).toBe(200);
      expect((await request(app).post('/api/departments').set(auth).send({ name: 'X' })).status).toBe(403);
      expect((await request(app).put(`/api/departments/${dept.id}`).set(auth).send({ name: 'Y' })).status).toBe(403);
      expect((await request(app).delete(`/api/departments/${dept.id}`).set(auth)).status).toBe(403);
    }
  });

  it('requires authentication', async () => {
    expect((await request(app).get('/api/departments')).status).toBe(401);
  });

  it('returns 400 for a malformed id and 404 for a missing one', async () => {
    const { auth } = await loginAs('admin');
    expect((await request(app).get('/api/departments/not-an-id').set(auth)).status).toBe(400);
    expect((await request(app).get('/api/departments/507f1f77bcf86cd799439011').set(auth)).status).toBe(404);
  });
});
