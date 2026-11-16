const Department = require('../models/Department');
const Employee = require('../models/Employee');
const ApiError = require('../utils/ApiError');

// GET /api/departments  - every department with its employee count (used for dropdowns too).
async function list(req, res) {
  const [departments, counts] = await Promise.all([
    Department.find().collation({ locale: 'en' }).sort({ name: 1 }),
    Employee.aggregate([{ $match: { department: { $ne: null } } }, { $group: { _id: '$department', count: { $sum: 1 } } }]),
  ]);

  const countById = new Map(counts.map((c) => [c._id.toString(), c.count]));
  const items = departments.map((d) => ({ ...d.toJSON(), employeeCount: countById.get(d.id) || 0 }));

  res.json({ success: true, data: { items } });
}

// GET /api/departments/:id
async function getOne(req, res) {
  const department = await Department.findById(req.params.id);
  if (!department) throw ApiError.notFound('Department not found');
  const employeeCount = await Employee.countDocuments({ department: department._id });
  res.json({ success: true, data: { department: { ...department.toJSON(), employeeCount } } });
}

// POST /api/departments  (admin)
async function create(req, res) {
  const { name, description } = req.body;
  const department = await Department.create({ name, description });
  res.status(201).json({ success: true, data: { department: { ...department.toJSON(), employeeCount: 0 } } });
}

// PUT /api/departments/:id  (admin)
async function update(req, res) {
  const updates = {};
  if (req.body.name !== undefined) updates.name = req.body.name;
  if (req.body.description !== undefined) updates.description = req.body.description;

  const department = await Department.findByIdAndUpdate(req.params.id, updates, { new: true, runValidators: true });
  if (!department) throw ApiError.notFound('Department not found');
  const employeeCount = await Employee.countDocuments({ department: department._id });
  res.json({ success: true, data: { department: { ...department.toJSON(), employeeCount } } });
}

// DELETE /api/departments/:id  (admin)
// Refuses while employees are still assigned, so nobody silently ends up without a department.
async function remove(req, res) {
  const department = await Department.findById(req.params.id);
  if (!department) throw ApiError.notFound('Department not found');

  const employeeCount = await Employee.countDocuments({ department: department._id });
  if (employeeCount > 0) {
    throw ApiError.conflict(
      `${department.name} still has ${employeeCount} employee(s). Reassign them before deleting.`
    );
  }

  await department.deleteOne();
  res.json({ success: true, message: 'Department deleted' });
}

module.exports = { list, getOne, create, update, remove };
