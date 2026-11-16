const { body, query } = require('express-validator');
const { ANNOUNCEMENT_CATEGORIES } = require('../models/Announcement');
const { MAX_LIMIT } = require('../utils/query');

function announcementFields({ requireCore }) {
  const core = (chain) => (requireCore ? chain : chain.optional());
  return [
    core(body('title')).trim().notEmpty().withMessage('Title is required').isLength({ max: 150 }).withMessage('Title is too long'),
    core(body('message')).trim().notEmpty().withMessage('Message is required').isLength({ max: 3000 }).withMessage('Message is too long'),
    body('category')
      .optional()
      .isIn(ANNOUNCEMENT_CATEGORIES)
      .withMessage(`Category must be one of: ${ANNOUNCEMENT_CATEGORIES.join(', ')}`),
    body('pinned').optional().isBoolean({ strict: true }).withMessage('pinned must be true or false'),
  ];
}

const createAnnouncementRules = announcementFields({ requireCore: true });
const updateAnnouncementRules = announcementFields({ requireCore: false });

const listAnnouncementRules = [
  query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
  query('limit').optional().isInt({ min: 1, max: MAX_LIMIT }).withMessage(`limit must be 1-${MAX_LIMIT}`),
  query('category').optional().isIn(ANNOUNCEMENT_CATEGORIES),
  query('search').optional().isString().isLength({ max: 100 }),
];

module.exports = { createAnnouncementRules, updateAnnouncementRules, listAnnouncementRules };
