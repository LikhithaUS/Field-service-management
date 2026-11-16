const { body, query } = require('express-validator');
const { TASK_STATUSES, TASK_PRIORITIES } = require('../models/Task');
const { MAX_LIMIT } = require('../utils/query');

const TASK_SORTS = ['createdAt', '-createdAt', 'dueDate', '-dueDate', 'title', '-title'];

// Fields shared by create and update; on update every field is optional.
function taskFields({ requireCore }) {
  const core = (chain) => (requireCore ? chain : chain.optional());
  return [
    core(body('title')).trim().notEmpty().withMessage('Title is required').isLength({ max: 150 }),
    core(body('assignedTo')).isMongoId().withMessage('Choose who the task is assigned to'),
    body('description').optional().trim().isLength({ max: 2000 }).withMessage('Description is too long'),
    body('location').optional().trim().isLength({ max: 200 }).withMessage('Location is too long'),
    body('priority')
      .optional()
      .isIn(TASK_PRIORITIES)
      .withMessage(`Priority must be one of: ${TASK_PRIORITIES.join(', ')}`),
    body('status')
      .optional()
      .isIn(TASK_STATUSES)
      .withMessage(`Status must be one of: ${TASK_STATUSES.join(', ')}`),
    // null/"" clears the due date.
    body('dueDate')
      .optional({ values: 'falsy' })
      .isISO8601()
      .withMessage('Invalid due date')
      .toDate(),
  ];
}

const createTaskRules = taskFields({ requireCore: true });
const updateTaskRules = taskFields({ requireCore: false });

const listTaskRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('search').optional().isString().isLength({ max: 100 }),
  query('status').optional().isIn(TASK_STATUSES),
  query('priority').optional().isIn(TASK_PRIORITIES),
  query('assignedTo').optional().isMongoId().withMessage('Invalid assignee'),
  query('mine').optional().isIn(['true', 'false']),
  query('overdue').optional().isIn(['true', 'false']),
  query('sort').optional().isIn(TASK_SORTS),
];

const commentRules = [
  body('message').trim().notEmpty().withMessage('Comment cannot be empty').isLength({ max: 1000 }).withMessage('Comment is too long'),
];

module.exports = { createTaskRules, updateTaskRules, listTaskRules, commentRules };
