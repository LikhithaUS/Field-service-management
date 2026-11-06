const { Router } = require('express');
const rateLimit = require('express-rate-limit');

const { config } = require('../config/env');
const controller = require('../controllers/auth.controller');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');
const {
  registerRules,
  loginRules,
  forgotPasswordRules,
  resetPasswordRules,
} = require('../validators/auth.validators');

const router = Router();

// Slows down brute-force password guessing (disabled in tests).
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skip: () => config.isTest,
  message: { success: false, message: 'Too many attempts, please try again later' },
});

router.post('/register', authLimiter, registerRules, validate, controller.register);
router.post('/login', authLimiter, loginRules, validate, controller.login);
router.post('/forgot-password', authLimiter, forgotPasswordRules, validate, controller.forgotPassword);
router.post('/reset-password', authLimiter, resetPasswordRules, validate, controller.resetPassword);
router.post('/logout', protect, controller.logout);
router.get('/me', protect, controller.me);

module.exports = router;
