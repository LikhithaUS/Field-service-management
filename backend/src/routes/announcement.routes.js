const { Router } = require('express');

const controller = require('../controllers/announcement.controller');
const { protect, authorize } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { ROLES } = require('../utils/roles');
const { idParam } = require('../validators/common.validators');
const {
  createAnnouncementRules,
  updateAnnouncementRules,
  listAnnouncementRules,
} = require('../validators/announcement.validators');

const router = Router();
const staff = authorize(ROLES.ADMIN, ROLES.MANAGER);

router.use(protect);

// Everyone reads; staff post. "Managers only change their own" is checked in the controller.
router.get('/', listAnnouncementRules, validate, controller.list);
router.get('/:id', idParam, validate, controller.getOne);
router.post('/', staff, createAnnouncementRules, validate, controller.create);
router.put('/:id', staff, idParam, updateAnnouncementRules, validate, controller.update);
router.delete('/:id', staff, idParam, validate, controller.remove);

module.exports = router;
