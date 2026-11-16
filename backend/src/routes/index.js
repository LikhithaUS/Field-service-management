const { Router } = require('express');
const authRoutes = require('./auth.routes');
const departmentRoutes = require('./department.routes');
const employeeRoutes = require('./employee.routes');
const taskRoutes = require('./task.routes');
const attendanceRoutes = require('./attendance.routes');

const router = Router();

router.use('/auth', authRoutes);
router.use('/departments', departmentRoutes);
router.use('/employees', employeeRoutes);
router.use('/tasks', taskRoutes);
router.use('/attendance', attendanceRoutes);
// Upcoming modules: leaves, notifications, dashboard

module.exports = router;
