const { Router } = require('express');

const controller = require('../controllers/employee.controller');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { ROLES } = require('../utils/roles');
const { idParam } = require('../validators/common.validators');
const {
  createEmployeeRules,
  updateEmployeeRules,
  listEmployeeRules,
} = require('../validators/employee.validators');

const router = Router();
const staff = authorize(ROLES.ADMIN, ROLES.MANAGER);

router.use(protect);

router.get('/', staff, listEmployeeRules, validate, controller.list);
router.get('/:id', staff, idParam, validate, controller.getOne);
router.post('/', staff, createEmployeeRules, validate, controller.create);
// Finer rules (managers can't edit admins/managers or change roles) live in the controller.
router.put('/:id', staff, idParam, updateEmployeeRules, validate, controller.update);
router.delete('/:id', authorize(ROLES.ADMIN), idParam, validate, controller.remove);

module.exports = router;
