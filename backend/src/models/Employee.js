const mongoose = require('mongoose');
const { ALL_ROLES, ROLES } = require('../utils/roles');

const EMPLOYEE_STATUSES = Object.freeze(['active', 'inactive']);

// The HR record. The login account lives in `users`; `user` links the two
// (and User.employeeId stores this record's employeeId).
const employeeSchema = new mongoose.Schema(
  {
    employeeId: { type: String, required: true, unique: true }, // e.g. EMP-0001
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', unique: true, sparse: true },
    name: { type: String, required: true, trim: true, maxlength: 100 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, trim: true, maxlength: 30, default: '' },
    profileImage: { type: String, default: null }, // filled in by the file-upload module
    designation: { type: String, trim: true, maxlength: 80, default: '' }, // job title
    department: { type: mongoose.Schema.Types.ObjectId, ref: 'Department', default: null },
    role: { type: String, enum: ALL_ROLES, default: ROLES.EMPLOYEE },
    joiningDate: { type: Date, default: Date.now },
    status: { type: String, enum: EMPLOYEE_STATUSES, default: 'active' },
  },
  { timestamps: true }
);

// Support the list screen's filters and default sort.
employeeSchema.index({ department: 1 });
employeeSchema.index({ role: 1, status: 1 });
employeeSchema.index({ name: 1 });

employeeSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Employee = mongoose.model('Employee', employeeSchema);

module.exports = Employee;
module.exports.EMPLOYEE_STATUSES = EMPLOYEE_STATUSES;
