const mongoose = require('mongoose');

const TASK_STATUSES = Object.freeze(['pending', 'in_progress', 'completed', 'cancelled']);
const TASK_PRIORITIES = Object.freeze(['low', 'medium', 'high', 'urgent']);
// Statuses that still need work; used for "overdue" (a finished task is never overdue).
const OPEN_STATUSES = Object.freeze(['pending', 'in_progress']);

// A unit of work assigned to one person. `assignedTo`/`assignedBy` reference login
// accounts (users), not employee records, because permissions are checked against req.user.
const taskSchema = new mongoose.Schema(
  {
    taskNumber: { type: String, required: true, unique: true }, // e.g. TSK-0001
    title: { type: String, required: true, trim: true, maxlength: 150 },
    description: { type: String, trim: true, maxlength: 2000, default: '' },
    location: { type: String, trim: true, maxlength: 200, default: '' }, // job site for field work
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assignedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    priority: { type: String, enum: TASK_PRIORITIES, default: 'medium' },
    status: { type: String, enum: TASK_STATUSES, default: 'pending' },
    // Stored as midnight UTC of the chosen day (a date, not a moment in time).
    dueDate: { type: Date, default: null },
    completedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// Keep completedAt in sync with status, whoever changes it.
taskSchema.pre('save', function syncCompletedAt() {
  if (!this.isModified('status')) return;
  this.completedAt = this.status === 'completed' ? new Date() : null;
});

// Support "my tasks" and the list filters.
taskSchema.index({ assignedTo: 1, status: 1 });
taskSchema.index({ status: 1, dueDate: 1 });
taskSchema.index({ createdAt: -1 });

taskSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Task = mongoose.model('Task', taskSchema);

module.exports = Task;
module.exports.TASK_STATUSES = TASK_STATUSES;
module.exports.TASK_PRIORITIES = TASK_PRIORITIES;
module.exports.OPEN_STATUSES = OPEN_STATUSES;
