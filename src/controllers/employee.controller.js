const crypto = require('crypto');

const Employee = require('../models/Employee');
const Department = require('../models/Department');
const Counter = require('../models/Counter');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { ROLES } = require('../utils/roles');
const { parsePagination, paginationMeta, escapeRegex } = require('../utils/query');
const { issueCode } = require('../services/code.service');
const { sendEmail } = require('../services/email.service');
const { welcomeEmail } = require('../services/email.templates');

const SORTS = {
  name: { name: 1 },
  '-name': { name: -1 },
  employeeId: { employeeId: 1 },
  '-employeeId': { employeeId: -1 },
  joiningDate: { joiningDate: 1 },
  '-joiningDate': { joiningDate: -1 },
  createdAt: { createdAt: 1 },
  '-createdAt': { createdAt: -1 },
};

const EDITABLE_FIELDS = ['name', 'email', 'phone', 'designation', 'department', 'role', 'joiningDate', 'status'];

const isManager = (user) => user.role === ROLES.MANAGER;

async function nextEmployeeId() {
  const seq = await Counter.next('employee');
  return `EMP-${String(seq).padStart(4, '0')}`;
}

async function assertDepartmentExists(departmentId) {
  if (!departmentId) return;
  if (!(await Department.exists({ _id: departmentId }))) throw ApiError.badRequest('Department not found');
}

// Business rule: managers may only create/assign the plain "employee" role.
function assertCanAssignRole(actor, role) {
  if (isManager(actor) && role !== ROLES.EMPLOYEE) {
    throw ApiError.forbidden('Managers can only assign the employee role');
  }
}

function populated(query) {
  return query.populate('department', 'name');
}

// GET /api/employees?search=&department=&role=&status=&sort=&page=&limit=
async function list(req, res) {
  const { search, department, role, status, sort } = req.query;
  const filter = {};

  if (search && search.trim()) {
    const rx = new RegExp(escapeRegex(search.trim()), 'i');
    filter.$or = [{ name: rx }, { email: rx }, { employeeId: rx }, { phone: rx }, { designation: rx }];
  }
  if (department) filter.department = department === 'none' ? null : department;
  if (role) filter.role = role;
  if (status) filter.status = status;

  const paging = parsePagination(req.query);
  const [items, total] = await Promise.all([
    populated(Employee.find(filter))
      .collation({ locale: 'en' })
      .sort(SORTS[sort] || SORTS.name)
      .skip(paging.skip)
      .limit(paging.limit),
    Employee.countDocuments(filter),
  ]);

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total) } });
}

// GET /api/employees/:id
async function getOne(req, res) {
  const employee = await populated(Employee.findById(req.params.id));
  if (!employee) throw ApiError.notFound('Employee not found');
  res.json({ success: true, data: { employee } });
}

// POST /api/employees  (admin, manager)
// Creates the HR record AND the login account. A new account gets an unguessable random
// password that nobody knows; the employee receives a setup code by email to choose their own.
// If the email already belongs to a self-registered account, that account is linked instead.
async function create(req, res) {
  const { name, email, phone, designation, department, joiningDate, status } = req.body;
  const role = req.body.role || ROLES.EMPLOYEE;

  assertCanAssignRole(req.user, role);
  await assertDepartmentExists(department);
  if (await Employee.exists({ email })) throw ApiError.conflict('An employee with this email already exists');

  let user = await User.findOne({ email });
  const accountCreated = !user;
  const previousUserState = user && { name: user.name, role: user.role, employeeId: user.employeeId };

  if (user) {
    if (isManager(req.user) && user.role !== ROLES.EMPLOYEE) {
      throw ApiError.forbidden('This email belongs to an admin/manager account');
    }
  } else {
    user = new User({ email, password: crypto.randomBytes(24).toString('hex') });
  }

  const employeeId = await nextEmployeeId();
  user.set({ name, role, employeeId, isActive: (status || 'active') === 'active' });
  await user.save();

  let employee;
  try {
    employee = await Employee.create({
      employeeId,
      user: user._id,
      name,
      email,
      phone,
      designation,
      department: department || null,
      role,
      joiningDate,
      status,
    });
  } catch (err) {
    // No multi-document transaction here (keeps local/in-memory MongoDB simple), so undo manually.
    if (accountCreated) await User.deleteOne({ _id: user._id });
    else {
      const { employeeId: prevId, ...rest } = previousUserState;
      await User.updateOne(
        { _id: user._id },
        prevId ? { $set: { ...rest, employeeId: prevId } } : { $set: rest, $unset: { employeeId: 1 } }
      );
    }
    throw err;
  }

  if (accountCreated) {
    const code = await issueCode(user, 'setup');
    await sendEmail(welcomeEmail(user, employee, code));
  }

  await employee.populate('department', 'name');
  res.status(201).json({ success: true, data: { employee, accountCreated } });
}

// PUT /api/employees/:id  (admin, manager)
async function update(req, res) {
  const employee = await Employee.findById(req.params.id);
  if (!employee) throw ApiError.notFound('Employee not found');

  const updates = {};
  for (const field of EDITABLE_FIELDS) {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  }

  if (isManager(req.user)) {
    if (employee.role !== ROLES.EMPLOYEE) throw ApiError.forbidden('Managers can only edit employees');
    if (updates.role !== undefined) assertCanAssignRole(req.user, updates.role);
  }

  // Don't let an admin lock themselves out by demoting or deactivating their own account.
  const isSelf = employee.user && employee.user.equals(req.user._id);
  if (isSelf && updates.role !== undefined && updates.role !== employee.role) {
    throw ApiError.badRequest('You cannot change your own role');
  }
  if (isSelf && updates.status === 'inactive') throw ApiError.badRequest('You cannot deactivate your own account');

  if (updates.department !== undefined) {
    updates.department = updates.department || null;
    await assertDepartmentExists(updates.department);
  }

  if (updates.email && updates.email !== employee.email) {
    const taken =
      (await Employee.exists({ email: updates.email, _id: { $ne: employee._id } })) ||
      (await User.exists({ email: updates.email, _id: { $ne: employee.user } }));
    if (taken) throw ApiError.conflict('Email is already in use');
  }

  const wasActive = employee.status === 'active';
  employee.set(updates);
  await employee.save();

  // Keep the login account in sync with the HR record.
  if (employee.user) {
    const userUpdate = { name: employee.name, email: employee.email, role: employee.role, isActive: employee.status === 'active' };
    const change = { $set: userUpdate };
    // Deactivation signs the person out everywhere immediately.
    if (wasActive && employee.status !== 'active') change.$inc = { tokenVersion: 1 };
    await User.updateOne({ _id: employee.user }, change);
  }

  await employee.populate('department', 'name');
  res.json({ success: true, data: { employee } });
}

// DELETE /api/employees/:id  (admin) - removes the HR record and its login account.
async function remove(req, res) {
  const employee = await Employee.findById(req.params.id);
  if (!employee) throw ApiError.notFound('Employee not found');
  if (employee.user && employee.user.equals(req.user._id)) {
    throw ApiError.badRequest('You cannot delete your own account');
  }

  await employee.deleteOne();
  if (employee.user) await User.deleteOne({ _id: employee.user });
  res.json({ success: true, message: 'Employee deleted' });
}

module.exports = { list, getOne, create, update, remove };
