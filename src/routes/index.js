const { Router } = require('express');
const authRoutes = require('./auth.routes');

const router = Router();

router.use('/auth', authRoutes);
// Upcoming modules: employees, departments, tasks, attendance, leaves, notifications, dashboard

module.exports = router;
