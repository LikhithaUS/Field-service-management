const { Router } = require('express');
const authRoutes = require('./auth.routes');
const departmentRoutes = require('./department.routes');
const employeeRoutes = require('./employee.routes');

const router = Router();

router.use('/auth', authRoutes);
router.use('/departments', departmentRoutes);
router.use('/employees', employeeRoutes);
// Upcoming modules: tasks, attendance, leaves, notifications, dashboard

module.exports = router;
