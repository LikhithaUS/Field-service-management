const mongoose = require('mongoose');

// "absent" isn't stored by check-in/out: a day without a record means absent.
// "leave" will be written by the leave module when a request is approved.
const ATTENDANCE_STATUSES = Object.freeze(['present', 'late', 'half_day', 'absent', 'leave']);

// One record per person per work day.
const attendanceSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, required: true }, // work day, midnight UTC (see utils/time.js)
    checkIn: { type: Date, default: null },
    checkOut: { type: Date, default: null },
    workingMinutes: { type: Number, default: 0, min: 0 },
    status: { type: String, enum: ATTENDANCE_STATUSES, default: 'present' },
  },
  { timestamps: true }
);

// The unique index is what really prevents a double check-in, even if two requests race.
attendanceSchema.index({ user: 1, date: 1 }, { unique: true });
attendanceSchema.index({ date: -1 });

attendanceSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Attendance = mongoose.model('Attendance', attendanceSchema);

module.exports = Attendance;
module.exports.ATTENDANCE_STATUSES = ATTENDANCE_STATUSES;
