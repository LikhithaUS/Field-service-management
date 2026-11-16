const { body } = require('express-validator');

const email = () => body('email').trim().isEmail().withMessage('A valid email is required').normalizeEmail();

// Shared with employee/password-reset flows so the rules stay identical everywhere.
const newPassword = (field = 'password') =>
  body(field)
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters')
    .matches(/[A-Za-z]/)
    .withMessage('Password must contain a letter')
    .matches(/\d/)
    .withMessage('Password must contain a number');

const registerRules = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 100 }),
  email(),
  newPassword(),
];

const loginRules = [email(), body('password').notEmpty().withMessage('Password is required')];

const forgotPasswordRules = [email()];

const resetPasswordRules = [
  email(),
  body('code')
    .trim()
    .matches(/^\d{6}$/)
    .withMessage('Code must be 6 digits'),
  newPassword(),
];

module.exports = { registerRules, loginRules, forgotPasswordRules, resetPasswordRules };
