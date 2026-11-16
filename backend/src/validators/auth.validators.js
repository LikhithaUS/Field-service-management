const { body } = require('express-validator');

const email = () => body('email').trim().isEmail().withMessage('A valid email is required').normalizeEmail();

// Shared with employee/password-reset flows so the rules stay identical everywhere.
// Any characters are allowed (symbols, spaces, unicode); these are the minimum requirements.
const newPassword = (field = 'password') =>
  body(field)
    .isString()
    .withMessage('Password is required')
    .isLength({ min: 8, max: 128 })
    .withMessage('Password must be 8-128 characters')
    .matches(/[A-Z]/)
    .withMessage('Password must contain an uppercase letter')
    .matches(/[a-z]/)
    .withMessage('Password must contain a lowercase letter')
    .matches(/\d/)
    .withMessage('Password must contain a number')
    .matches(/[^A-Za-z0-9]/)
    .withMessage('Password must contain a special character (e.g. ! @ # $ %)');

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
