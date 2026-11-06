const { body } = require('express-validator');

const createDepartmentRules = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 60 }),
  body('description').optional().trim().isLength({ max: 300 }).withMessage('Max 300 characters'),
];

const updateDepartmentRules = [
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty').isLength({ max: 60 }),
  body('description').optional().trim().isLength({ max: 300 }).withMessage('Max 300 characters'),
];

module.exports = { createDepartmentRules, updateDepartmentRules };
