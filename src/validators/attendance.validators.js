const { query } = require('express-validator');
const { ATTENDANCE_STATUSES } = require('../models/Attendance');
const { MAX_LIMIT } = require('../utils/query');

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

const listAttendanceRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('from').optional().matches(DATE_ONLY).withMessage('from must be YYYY-MM-DD'),
  query('to')
    .optional()
    .matches(DATE_ONLY)
    .withMessage('to must be YYYY-MM-DD')
    .custom((to, { req }) => !req.query.from || to >= req.query.from)
    .withMessage('to must be on or after from'),
  query('user').optional().isMongoId().withMessage('Invalid user'),
  query('status').optional().isIn(ATTENDANCE_STATUSES),
];

module.exports = { listAttendanceRules };
