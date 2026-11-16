const { Router } = require('express');

const controller = require('../controllers/attendance.controller');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { listAttendanceRules } = require('../validators/attendance.validators');

const router = Router();

router.use(protect);

// Everyone marks their own attendance. The list is scoped by role inside the controller.
router.get('/today', controller.today);
router.post('/check-in', controller.checkIn);
router.post('/check-out', controller.checkOut);
router.get('/', listAttendanceRules, validate, controller.list);

module.exports = router;
