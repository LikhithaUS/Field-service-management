const { body, query } = require('express-validator');
const { ALL_ROLES } = require('../utils/roles');
const { EMPLOYEE_STATUSES } = require('../models/Employee');
const { MAX_LIMIT } = require('../utils/query');

// Fields shared by create and update; `optional` controls whether name/email are required.
function employeeFields({ requireCore }) {
  const core = (chain) => (requireCore ? chain : chain.optional());
  return [
    core(body('name')).trim().notEmpty().withMessage('Name is required').isLength({ max: 100 }),
    core(body('email')).trim().isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('phone')
      .optional({ values: 'falsy' })
      .trim()
      .matches(/^[+\d][\d\s()-]{5,29}$/)
      .withMessage('Enter a valid phone number'),
    body('designation').optional().trim().isLength({ max: 80 }),
    body('department')
      .optional({ values: 'null' })
      .custom((v) => v === '' || /^[a-f\d]{24}$/i.test(v))
      .withMessage('Invalid department'),
    body('role').optional().isIn(ALL_ROLES).withMessage(`Role must be one of: ${ALL_ROLES.join(', ')}`),
    body('status')
      .optional()
      .isIn(EMPLOYEE_STATUSES)
      .withMessage(`Status must be one of: ${EMPLOYEE_STATUSES.join(', ')}`),
    body('joiningDate').optional().isISO8601().withMessage('Invalid date').toDate(),
  ];
}

const createEmployeeRules = employeeFields({ requireCore: true });
const updateEmployeeRules = employeeFields({ requireCore: false });

const listEmployeeRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('search').optional().isString().isLength({ max: 100 }),
  query('department')
    .optional()
    .custom((v) => v === 'none' || /^[a-f\d]{24}$/i.test(v))
    .withMessage('Invalid department'),
  query('role').optional().isIn(ALL_ROLES),
  query('status').optional().isIn(EMPLOYEE_STATUSES),
];

module.exports = { createEmployeeRules, updateEmployeeRules, listEmployeeRules };
