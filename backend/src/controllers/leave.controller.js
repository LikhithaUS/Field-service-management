const Leave = require('../models/Leave');
const Attendance = require('../models/Attendance');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { config } = require('../config/env');
const { ROLES } = require('../utils/roles');
const { parsePagination, paginationMeta } = require('../utils/query');
const { clock, workDate } = require('../utils/time');
const { sendEmail } = require('../services/email.service');
const { leaveDecisionEmail } = require('../services/email.templates');

const { ACTIVE_STATUSES } = Leave;
const PERSON_FIELDS = 'name email role employeeId';
const PEOPLE = [
  { path: 'user', select: PERSON_FIELDS },
  { path: 'reviewedBy', select: PERSON_FIELDS },
];
const DAY_MS = 24 * 60 * 60 * 1000;

const isStaff = (user) => user.role === ROLES.ADMIN || user.role === ROLES.MANAGER;
const ownerId = (leave) => leave.user._id || leave.user; // populated or not
const isOwner = (leave, user) => ownerId(leave).equals(user._id);
const toDate = (yyyyMmDd) => new Date(`${yyyyMmDd}T00:00:00.000Z`);
const today = () => workDate(clock.now(), config.attendance.timeZone);

/** Every Mon-Fri date in [start, end], as midnight UTC. Weekends don't count as leave. */
function workingDays(start, end) {
  const days = [];
  for (let t = start.getTime(); t <= end.getTime(); t += DAY_MS) {
    const d = new Date(t);
    const weekday = d.getUTCDay();
    if (weekday !== 0 && weekday !== 6) days.push(d);
  }
  return days;
}

async function findVisibleLeave(req) {
  const leave = await Leave.findById(req.params.id).populate(PEOPLE);
  if (!leave || (!isStaff(req.user) && !isOwner(leave, req.user))) throw ApiError.notFound('Leave request not found');
  return leave;
}

// Approve/reject rules: staff only, never your own request, and managers only review employees.
function assertCanReview(leave, reviewer) {
  if (isOwner(leave, reviewer)) throw ApiError.forbidden('You cannot review your own leave request');
  if (reviewer.role === ROLES.MANAGER && leave.user.role !== ROLES.EMPLOYEE) {
    throw ApiError.forbidden('Managers can only review leave requests from employees');
  }
  if (leave.status !== 'pending') throw ApiError.conflict(`This request is already ${leave.status}`);
}

// Approved leave shows up in attendance. A day the person actually checked in is left alone.
async function markAttendanceAsLeave(leave) {
  const userId = ownerId(leave);
  await Promise.all(
    workingDays(leave.startDate, leave.endDate).map((date) =>
      Attendance.updateOne(
        { user: userId, date, checkIn: null },
        { $set: { status: 'leave' }, $setOnInsert: { user: userId, date } },
        { upsert: true }
      ).catch((err) => {
        // A record with a check-in exists, so the upsert's insert collides with the unique index: skip it.
        if (err.code !== 11000) throw err;
      })
    )
  );
}

async function clearAttendanceLeave(leave) {
  await Attendance.deleteMany({
    user: ownerId(leave),
    date: { $gte: leave.startDate, $lte: leave.endDate },
    status: 'leave',
    checkIn: null,
  });
}

// GET /api/leaves?status=&leaveType=&user=&mine=&page=&limit=
async function list(req, res) {
  const { status, leaveType, user, mine } = req.query;
  const filter = {};

  if (!isStaff(req.user) || mine === 'true') filter.user = req.user._id;
  else if (user) filter.user = user;
  if (status) filter.status = status;
  if (leaveType) filter.leaveType = leaveType;

  const paging = parsePagination(req.query);
  const [items, total] = await Promise.all([
    Leave.find(filter).sort({ startDate: -1, createdAt: -1 }).skip(paging.skip).limit(paging.limit).populate(PEOPLE),
    Leave.countDocuments(filter),
  ]);

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total) } });
}

// GET /api/leaves/:id
async function getOne(req, res) {
  const leave = await findVisibleLeave(req);
  res.json({ success: true, data: { leave } });
}

// POST /api/leaves  - anyone applies for themselves.
async function apply(req, res) {
  const { leaveType, reason } = req.body;
  const startDate = toDate(req.body.startDate);
  const endDate = toDate(req.body.endDate);

  // Sick leave is often reported afterwards; other leave must be planned ahead.
  if (leaveType !== 'sick' && startDate < today()) {
    throw ApiError.badRequest('Only sick leave can start in the past');
  }

  const days = workingDays(startDate, endDate).length;
  if (days === 0) throw ApiError.badRequest('The selected dates contain no working days');

  const overlapping = await Leave.exists({
    user: req.user._id,
    status: { $in: ACTIVE_STATUSES },
    startDate: { $lte: endDate },
    endDate: { $gte: startDate },
  });
  if (overlapping) throw ApiError.conflict('You already have a leave request for some of these dates');

  const leave = await Leave.create({ user: req.user._id, leaveType, startDate, endDate, days, reason });
  await leave.populate(PEOPLE);
  res.status(201).json({ success: true, data: { leave } });
}

async function review(req, res, status) {
  const leave = await Leave.findById(req.params.id).populate(PEOPLE);
  if (!leave) throw ApiError.notFound('Leave request not found');
  assertCanReview(leave, req.user);

  // Express 5 leaves req.body undefined when the request has no body (a review without a note).
  leave.set({ status, reviewedBy: req.user._id, reviewedAt: clock.now(), reviewNote: req.body?.note || '' });
  await leave.save();
  if (status === 'approved') await markAttendanceAsLeave(leave);

  await leave.populate(PEOPLE);
  const owner = await User.findById(ownerId(leave));
  if (owner) await sendEmail(leaveDecisionEmail(owner, leave, req.user));

  res.json({ success: true, data: { leave } });
}

// PUT /api/leaves/:id/approve  (admin, manager)
const approve = (req, res) => review(req, res, 'approved');

// PUT /api/leaves/:id/reject  (admin, manager)
const reject = (req, res) => review(req, res, 'rejected');

// PUT /api/leaves/:id/cancel  - the requester withdraws it: while pending,
// or once approved as long as the leave hasn't started yet.
async function cancel(req, res) {
  const leave = await findVisibleLeave(req);
  if (!isOwner(leave, req.user)) throw ApiError.forbidden('Only the person who applied can cancel this request');

  const cancellable = leave.status === 'pending' || (leave.status === 'approved' && leave.startDate > today());
  if (!cancellable) {
    throw ApiError.conflict(
      leave.status === 'approved' ? 'Leave that has already started cannot be cancelled' : `This request is already ${leave.status}`
    );
  }

  const wasApproved = leave.status === 'approved';
  leave.status = 'cancelled';
  await leave.save();
  if (wasApproved) await clearAttendanceLeave(leave);

  res.json({ success: true, data: { leave } });
}

module.exports = { list, getOne, apply, approve, reject, cancel, workingDays };
