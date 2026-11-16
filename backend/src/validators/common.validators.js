const { param } = require('express-validator');

const idParam = [param('id').isMongoId().withMessage('Invalid id')];

module.exports = { idParam };
