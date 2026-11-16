const mongoose = require('mongoose');

const LEAVE_TYPES = Object.freeze(['casual', 'sick', 'annual', 'other']);
const LEAVE_STATUSES = Object.freeze(['pending', 'approved', 'rejected', 'cancelled']);
// Requests that still "hold" their dates; a new request may not overlap these.
const ACTIVE_STATUSES = Object.freeze(['pending', 'approved']);

const leaveSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // who is taking leave
    leaveType: { type: String, enum: LEAVE_TYPES, required: true },
    // Calendar dates (inclusive), stored as midnight UTC like task due dates and attendance days.
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    days: { type: Number, required: true, min: 1 }, // working days (Mon-Fri) in the range
    reason: { type: String, required: true, trim: true, maxlength: 500 },
    status: { type: String, enum: LEAVE_STATUSES, default: 'pending' },
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    reviewedAt: { type: Date, default: null },
    reviewNote: { type: String, trim: true, maxlength: 300, default: '' },
  },
  { timestamps: true }
);

leaveSchema.index({ user: 1, startDate: -1 });
leaveSchema.index({ status: 1, startDate: 1 });

leaveSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Leave = mongoose.model('Leave', leaveSchema);

module.exports = Leave;
module.exports.LEAVE_TYPES = LEAVE_TYPES;
module.exports.LEAVE_STATUSES = LEAVE_STATUSES;
module.exports.ACTIVE_STATUSES = ACTIVE_STATUSES;
