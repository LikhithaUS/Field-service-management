const { app, request, loginAs, lastCodeFor, outbox } = require('./helpers');
const Department = require('../src/models/Department');
const Employee = require('../src/models/Employee');
const User = require('../src/models/User');

const newEmployee = (overrides = {}) => ({
  name: 'Priya Sharma',
  email: 'priya@example.com',
  phone: '+91 98765 43210',
  designation: 'Field Technician',
  ...overrides,
});

describe('POST /api/employees', () => {
  it('creates the employee + login account and emails a setup code', async () => {
    const { auth } = await loginAs('admin');
    const dept = await Department.create({ name: 'Operations' });

    const res = await request(app)
      .post('/api/employees')
      .set(auth)
      .send(newEmployee({ department: dept.id }));

    expect(res.status).toBe(201);
    expect(res.body.data.accountCreated).toBe(true);
    const emp = res.body.data.employee;
    expect(emp).toMatchObject({
      employeeId: 'EMP-0001',
      name: 'Priya Sharma',
      role: 'employee',
      status: 'active',
      department: { id: dept.id, name: 'Operations' },
    });

    const user = await User.findOne({ email: 'priya@example.com' });
    expect(user.employeeId).toBe('EMP-0001');
    expect(user.role).toBe('employee');

    // The welcome email's code lets the employee set their own password and sign in.
    const code = lastCodeFor('priya@example.com');
    expect(code).toMatch(/^\d{6}$/);
    const reset = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'priya@example.com', code, password: 'mypass123' });
    expect(reset.status).toBe(200);
    expect(reset.body.data.user.employeeId).toBe('EMP-0001');
  });

  it('generates sequential employee IDs', async () => {
    const { auth } = await loginAs('admin');
    await request(app).post('/api/employees').set(auth).send(newEmployee({ email: 'a@example.com' }));
    const second = await request(app).post('/api/employees').set(auth).send(newEmployee({ email: 'b@example.com' }));
    expect(second.body.data.employee.employeeId).toBe('EMP-0002');
  });

  it('links an existing self-registered account instead of creating a new one', async () => {
    const { auth } = await loginAs('admin');
    await request(app).post('/api/auth/register').send({ name: 'Priya', email: 'priya@example.com', password: 'selfpass1' });

    const res = await request(app).post('/api/employees').set(auth).send(newEmployee());
    expect(res.status).toBe(201);
    expect(res.body.data.accountCreated).toBe(false);
    expect(outbox).toHaveLength(0); // they already have a password
    expect(await User.countDocuments({ email: 'priya@example.com' })).toBe(1);

    // Their existing password still works.
    const login = await request(app).post('/api/auth/login').send({ email: 'priya@example.com', password: 'selfpass1' });
    expect(login.status).toBe(200);
  });

  it('rejects a duplicate employee email', async () => {
    const { auth } = await loginAs('admin');
    await request(app).post('/api/employees').set(auth).send(newEmployee());
    const dup = await request(app).post('/api/employees').set(auth).send(newEmployee({ name: 'Other' }));
    expect(dup.status).toBe(409);
  });

  it('rejects an unknown department and invalid fields', async () => {
    const { auth } = await loginAs('admin');
    const badDept = await request(app)
      .post('/api/employees')
      .set(auth)
      .send(newEmployee({ department: '507f1f77bcf86cd799439011' }));
    expect(badDept.status).toBe(400);
    expect(await User.countDocuments({ email: 'priya@example.com' })).toBe(0);

    const invalid = await request(app)
      .post('/api/employees')
      .set(auth)
      .send({ name: '', email: 'nope', role: 'boss', phone: 'abc' });
    expect(invalid.status).toBe(400);
    const fields = invalid.body.details.map((d) => d.field);
    expect(fields).toEqual(expect.arrayContaining(['name', 'email', 'role', 'phone']));
  });

  it('managers can create employees but not managers/admins', async () => {
    const { auth } = await loginAs('manager');
    const ok = await request(app).post('/api/employees').set(auth).send(newEmployee());
    expect(ok.status).toBe(201);

    const bad = await request(app)
      .post('/api/employees')
      .set(auth)
      .send(newEmployee({ email: 'boss@example.com', role: 'manager' }));
    expect(bad.status).toBe(403);
  });

  it('employees cannot create employees', async () => {
    const { auth } = await loginAs('employee');
    const res = await request(app).post('/api/employees').set(auth).send(newEmployee());
    expect(res.status).toBe(403);
  });
});

describe('GET /api/employees (search, filters, pagination)', () => {
  let auth;
  let it1;
  let hr;

  beforeEach(async () => {
    ({ auth } = await loginAs('admin'));
    it1 = await Department.create({ name: 'IT' });
    hr = await Department.create({ name: 'HR' });
    const people = [
      { name: 'Anil Kumar', email: 'anil@x.com', department: it1._id, role: 'manager' },
      { name: 'Bhavna Rao', email: 'bhavna@x.com', department: it1._id },
      { name: 'Chetan Das', email: 'chetan@x.com', department: hr._id, status: 'inactive' },
      { name: 'Divya Nair', email: 'divya@x.com', department: hr._id },
      { name: 'Esha Gupta', email: 'esha@x.com' },
    ];
    await Employee.insertMany(people.map((p, i) => ({ ...p, employeeId: `EMP-000${i + 1}` })));
  });

  it('paginates and sorts by name by default', async () => {
    const res = await request(app).get('/api/employees?limit=2&page=2').set(auth);
    expect(res.status).toBe(200);
    expect(res.body.data.items.map((e) => e.name)).toEqual(['Chetan Das', 'Divya Nair']);
    expect(res.body.data.pagination).toEqual({ page: 2, limit: 2, total: 5, totalPages: 3 });
  });

  it('searches name, email and employee ID (case-insensitive)', async () => {
    const byName = await request(app).get('/api/employees?search=RAO').set(auth);
    expect(byName.body.data.items.map((e) => e.name)).toEqual(['Bhavna Rao']);

    const byId = await request(app).get('/api/employees?search=EMP-0004').set(auth);
    expect(byId.body.data.items.map((e) => e.name)).toEqual(['Divya Nair']);
  });

  it('treats regex characters in search literally', async () => {
    const res = await request(app).get(`/api/employees?search=${encodeURIComponent('.*')}`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.data.items).toHaveLength(0);
  });

  it('filters by department, role, status and "no department"', async () => {
    const byDept = await request(app).get(`/api/employees?department=${hr.id}`).set(auth);
    expect(byDept.body.data.items.map((e) => e.name)).toEqual(['Chetan Das', 'Divya Nair']);

    const byRole = await request(app).get('/api/employees?role=manager').set(auth);
    expect(byRole.body.data.items.map((e) => e.name)).toEqual(['Anil Kumar']);

    const byStatus = await request(app).get('/api/employees?status=inactive').set(auth);
    expect(byStatus.body.data.items.map((e) => e.name)).toEqual(['Chetan Das']);

    const none = await request(app).get('/api/employees?department=none').set(auth);
    expect(none.body.data.items.map((e) => e.name)).toEqual(['Esha Gupta']);

    const combined = await request(app).get(`/api/employees?department=${it1.id}&role=employee`).set(auth);
    expect(combined.body.data.items.map((e) => e.name)).toEqual(['Bhavna Rao']);
  });

  it('includes the department name', async () => {
    const res = await request(app).get('/api/employees?search=anil').set(auth);
    expect(res.body.data.items[0].department).toEqual({ id: it1.id, name: 'IT' });
  });

  it('validates query params', async () => {
    expect((await request(app).get('/api/employees?limit=500').set(auth)).status).toBe(400);
    expect((await request(app).get('/api/employees?role=boss').set(auth)).status).toBe(400);
  });

  it('is not available to employees', async () => {
    const emp = await loginAs('employee');
    expect((await request(app).get('/api/employees').set(emp.auth)).status).toBe(403);
  });
});

describe('PUT /api/employees/:id', () => {
  async function createVia(auth, overrides) {
    const res = await request(app).post('/api/employees').set(auth).send(newEmployee(overrides));
    return res.body.data.employee;
  }

  it('updates the record and keeps the login account in sync', async () => {
    const { auth } = await loginAs('admin');
    const emp = await createVia(auth);

    const res = await request(app)
      .put(`/api/employees/${emp.id}`)
      .set(auth)
      .send({ name: 'Priya S', email: 'priya.s@example.com', role: 'manager' });
    expect(res.status).toBe(200);

    const user = await User.findOne({ employeeId: emp.employeeId });
    expect(user).toMatchObject({ name: 'Priya S', email: 'priya.s@example.com', role: 'manager' });
  });

  it('deactivating an employee blocks login and revokes their sessions', async () => {
    const { auth } = await loginAs('admin');
    const emp = await createVia(auth);
    const code = lastCodeFor('priya@example.com');
    const setup = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'priya@example.com', code, password: 'mypass123' });
    const priyaAuth = { Authorization: `Bearer ${setup.body.data.token}` };

    await request(app).put(`/api/employees/${emp.id}`).set(auth).send({ status: 'inactive' });

    expect((await request(app).get('/api/auth/me').set(priyaAuth)).status).toBe(401);
    const login = await request(app).post('/api/auth/login').send({ email: 'priya@example.com', password: 'mypass123' });
    expect(login.status).toBe(403);
  });

  it('managers can edit employees but cannot change roles or edit managers', async () => {
    const admin = await loginAs('admin');
    const manager = await loginAs('manager');
    const emp = await createVia(admin.auth);
    const otherManager = await createVia(admin.auth, { email: 'm2@example.com', role: 'manager' });

    const ok = await request(app).put(`/api/employees/${emp.id}`).set(manager.auth).send({ designation: 'Senior Technician' });
    expect(ok.status).toBe(200);

    const promote = await request(app).put(`/api/employees/${emp.id}`).set(manager.auth).send({ role: 'admin' });
    expect(promote.status).toBe(403);

    const editManager = await request(app).put(`/api/employees/${otherManager.id}`).set(manager.auth).send({ phone: '+1 555 0100' });
    expect(editManager.status).toBe(403);
  });

  it('an admin cannot demote or deactivate themselves', async () => {
    const { auth } = await loginAs('admin', { email: 'root@example.com' });
    // Link the admin's own account to an employee record.
    const self = await createVia(auth, { email: 'root@example.com', role: 'admin', name: 'Root' });

    expect((await request(app).put(`/api/employees/${self.id}`).set(auth).send({ role: 'employee' })).status).toBe(400);
    expect((await request(app).put(`/api/employees/${self.id}`).set(auth).send({ status: 'inactive' })).status).toBe(400);
  });

  it('rejects changing email to one already in use', async () => {
    const { auth } = await loginAs('admin');
    const a = await createVia(auth, { email: 'a@example.com' });
    await createVia(auth, { email: 'b@example.com' });
    const res = await request(app).put(`/api/employees/${a.id}`).set(auth).send({ email: 'b@example.com' });
    expect(res.status).toBe(409);
  });
});

describe('DELETE /api/employees/:id', () => {
  it('admin deletes the employee and their login account', async () => {
    const { auth } = await loginAs('admin');
    const created = await request(app).post('/api/employees').set(auth).send(newEmployee());
    const { id } = created.body.data.employee;

    const res = await request(app).delete(`/api/employees/${id}`).set(auth);
    expect(res.status).toBe(200);
    expect(await Employee.countDocuments()).toBe(0);
    expect(await User.exists({ email: 'priya@example.com' })).toBeNull();
  });

  it('managers cannot delete', async () => {
    const admin = await loginAs('admin');
    const manager = await loginAs('manager');
    const created = await request(app).post('/api/employees').set(admin.auth).send(newEmployee());
    const res = await request(app).delete(`/api/employees/${created.body.data.employee.id}`).set(manager.auth);
    expect(res.status).toBe(403);
  });

  it('an admin cannot delete their own record', async () => {
    const { auth } = await loginAs('admin', { email: 'root@example.com' });
    const self = await request(app)
      .post('/api/employees')
      .set(auth)
      .send(newEmployee({ email: 'root@example.com', role: 'admin' }));
    const res = await request(app).delete(`/api/employees/${self.body.data.employee.id}`).set(auth);
    expect(res.status).toBe(400);
  });
});
