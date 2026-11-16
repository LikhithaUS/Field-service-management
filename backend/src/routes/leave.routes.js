const { Router } = require('express');

const controller = require('../controllers/leave.controller');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { ROLES } = require('../utils/roles');
const { idParam } = require('../validators/common.validators');
const { applyLeaveRules, reviewRules, listLeaveRules } = require('../validators/leave.validators');

const router = Router();
const staff = authorize(ROLES.ADMIN, ROLES.MANAGER);

router.use(protect);

// Everyone applies for and sees their own leave; staff also see and review everyone's.
// Finer review rules (not your own, managers only review employees) live in the controller.
router.get('/', listLeaveRules, validate, controller.list);
router.get('/:id', idParam, validate, controller.getOne);
router.post('/', applyLeaveRules, validate, controller.apply);
router.put('/:id/approve', staff, idParam, reviewRules, validate, controller.approve);
router.put('/:id/reject', staff, idParam, reviewRules, validate, controller.reject);
router.put('/:id/cancel', idParam, validate, controller.cancel);

module.exports = router;
