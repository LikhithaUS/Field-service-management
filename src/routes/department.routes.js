const { Router } = require('express');

const controller = require('../controllers/department.controller');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { ROLES } = require('../utils/roles');
const { idParam } = require('../validators/common.validators');
const { createDepartmentRules, updateDepartmentRules } = require('../validators/department.validators');

const router = Router();
const adminOnly = authorize(ROLES.ADMIN);

router.use(protect);

// Any signed-in user can read departments (needed for dropdowns and profiles).
router.get('/', controller.list);
router.get('/:id', idParam, validate, controller.getOne);

router.post('/', adminOnly, createDepartmentRules, validate, controller.create);
router.put('/:id', adminOnly, idParam, updateDepartmentRules, validate, controller.update);
router.delete('/:id', adminOnly, idParam, validate, controller.remove);

module.exports = router;
