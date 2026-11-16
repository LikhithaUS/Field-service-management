const mongoose = require('mongoose');

const Attendance = require('../models/Attendance');
const ApiError = require('../utils/ApiError');
const { config } = require('../config/env');
const { ROLES } = require('../utils/roles');
const { parsePagination, paginationMeta } = require('../utils/query');
const { clock, workDate, minutesOfDay, parseHHmm } = require('../utils/time');

const { timeZone, workStart, halfDayHours } = config.attendance;
const PERSON_FIELDS = 'name email role employeeId';

const isStaff = (user) => user.role === ROLES.ADMIN || user.role === ROLES.MANAGER;

// Sent with "today" so the app can explain the rules instead of hard-coding them.
const rules = () => ({ timeZone, workStart, halfDayHours });

// GET /api/attendance/today - the signed-in user's record for today (null before check-in).
async function today(req, res) {
  const date = workDate(clock.now(), timeZone);
  const attendance = await Attendance.findOne({ user: req.user._id, date });
  res.json({ success: true, data: { date, attendance, rules: rules() } });
}

// POST /api/attendance/check-in
async function checkIn(req, res) {
  const now = clock.now();
  const date = workDate(now, timeZone);
  const late = minutesOfDay(now, timeZone) > parseHHmm(workStart);

  try {
    const attendance = await Attendance.create({
      user: req.user._id,
      date,
      checkIn: now,
      status: late ? 'late' : 'present',
    });
    res.status(201).json({ success: true, data: { attendance } });
  } catch (err) {
    // The unique (user, date) index rejects a second check-in on the same day.
    if (err.code === 11000) throw ApiError.conflict('You have already checked in today');
    throw err;
  }
}

// POST /api/attendance/check-out
async function checkOut(req, res) {
  const now = clock.now();
  const attendance = await Attendance.findOne({ user: req.user._id, date: workDate(now, timeZone) });
  if (!attendance || !attendance.checkIn) throw ApiError.badRequest('You have not checked in today');
  if (attendance.checkOut) throw ApiError.conflict('You have already checked out today');

  attendance.checkOut = now;
  attendance.workingMinutes = Math.floor((now - attendance.checkIn) / 60000);
  // Leaving early downgrades the day, whether the check-in was on time or late.
  if (attendance.workingMinutes < halfDayHours * 60) attendance.status = 'half_day';
  await attendance.save();

  res.json({ success: true, data: { attendance } });
}

// GET /api/attendance?from=&to=&user=&status=&page=&limit=
// Employees get their own history; staff see everyone (optionally one person).
// Also returns a summary of the whole filtered range, not just the current page.
async function list(req, res) {
  const { from, to, user, status } = req.query;
  const filter = {};

  if (!isStaff(req.user)) filter.user = req.user._id;
  else if (user) filter.user = new mongoose.Types.ObjectId(String(user));

  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = new Date(`${from}T00:00:00.000Z`);
    if (to) filter.date.$lte = new Date(`${to}T00:00:00.000Z`);
  }
  if (status) filter.status = status;

  const paging = parsePagination(req.query);
  const [items, total, byStatus] = await Promise.all([
    Attendance.find(filter)
      .sort({ date: -1, checkIn: -1 })
      .skip(paging.skip)
      .limit(paging.limit)
      .populate('user', PERSON_FIELDS),
    Attendance.countDocuments(filter),
    // aggregate() skips Mongoose casting, which is why `user` was converted to an ObjectId above.
    Attendance.aggregate([
      { $match: filter },
      { $group: { _id: '$status', days: { $sum: 1 }, minutes: { $sum: '$workingMinutes' } } },
    ]),
  ]);

  const summary = { present: 0, late: 0, half_day: 0, absent: 0, leave: 0, totalMinutes: 0 };
  for (const row of byStatus) {
    summary[row._id] = row.days;
    summary.totalMinutes += row.minutes;
  }

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total), summary } });
}

module.exports = { today, checkIn, checkOut, list };
