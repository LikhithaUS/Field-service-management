const { Router } = require('express');
const { query } = require('express-validator');

const controller = require('../controllers/notification.controller');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { idParam } = require('../validators/common.validators');
const { MAX_LIMIT } = require('../utils/query');

const router = Router();

const listRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('unread').optional().isIn(['true', 'false']),
];

router.use(protect);

router.get('/', listRules, validate, controller.list);
router.get('/unread-count', controller.unreadCount);
// 'read-all' is declared before '/:id/read' for readability; the paths can't collide anyway.
router.put('/read-all', controller.markAllRead);
router.put('/:id/read', idParam, validate, controller.markRead);

module.exports = router;
