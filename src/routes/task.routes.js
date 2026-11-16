const { Router } = require('express');

const controller = require('../controllers/task.controller');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { ROLES } = require('../utils/roles');
const { idParam } = require('../validators/common.validators');
const { createTaskRules, updateTaskRules, listTaskRules, commentRules } = require('../validators/task.validators');

const router = Router();
const staff = authorize(ROLES.ADMIN, ROLES.MANAGER);

router.use(protect);

// Everyone can list/view/update/comment, but employees only reach tasks assigned to them
// and can only change the status. Those finer rules live in the controller.
router.get('/', listTaskRules, validate, controller.list);
router.get('/:id', idParam, validate, controller.getOne);
router.post('/', staff, createTaskRules, validate, controller.create);
router.put('/:id', idParam, updateTaskRules, validate, controller.update);
router.delete('/:id', staff, idParam, validate, controller.remove);

router.get('/:id/comments', idParam, validate, controller.listComments);
router.post('/:id/comments', idParam, commentRules, validate, controller.addComment);

module.exports = router;
