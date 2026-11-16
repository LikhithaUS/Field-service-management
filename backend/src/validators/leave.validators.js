const { body, query } = require('express-validator');
const { LEAVE_TYPES, LEAVE_STATUSES } = require('../models/Leave');
const { MAX_LIMIT } = require('../utils/query');

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;
const isRealDate = (v) => !Number.isNaN(new Date(`${v}T00:00:00.000Z`).getTime());

const applyLeaveRules = [
  body('leaveType').isIn(LEAVE_TYPES).withMessage(`Leave type must be one of: ${LEAVE_TYPES.join(', ')}`),
  body('startDate').matches(DATE_ONLY).custom(isRealDate).withMessage('Start date must be YYYY-MM-DD'),
  body('endDate')
    .matches(DATE_ONLY)
    .custom(isRealDate)
    .withMessage('End date must be YYYY-MM-DD')
    .custom((end, { req }) => typeof req.body.startDate !== 'string' || end >= req.body.startDate)
    .withMessage('End date must be on or after the start date'),
  body('reason').trim().notEmpty().withMessage('Reason is required').isLength({ max: 500 }).withMessage('Reason is too long'),
];

const reviewRules = [body('note').optional().trim().isLength({ max: 300 }).withMessage('Note is too long')];

const listLeaveRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('status').optional().isIn(LEAVE_STATUSES),
  query('leaveType').optional().isIn(LEAVE_TYPES),
  query('user').optional().isMongoId().withMessage('Invalid user'),
  query('mine').optional().isIn(['true', 'false']),
];

module.exports = { applyLeaveRules, reviewRules, listLeaveRules };
