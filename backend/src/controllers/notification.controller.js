const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');
const { parsePagination, paginationMeta } = require('../utils/query');

// Everything here is scoped to the signed-in user: you only ever see your own notifications.

// GET /api/notifications?unread=true&page=&limit=
async function list(req, res) {
  const filter = { user: req.user._id };
  if (req.query.unread === 'true') filter.isRead = false;

  const paging = parsePagination(req.query);
  const [items, total, unreadCount] = await Promise.all([
    Notification.find(filter).sort({ createdAt: -1 }).skip(paging.skip).limit(paging.limit),
    Notification.countDocuments(filter),
    Notification.countDocuments({ user: req.user._id, isRead: false }),
  ]);

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total), unreadCount } });
}

// GET /api/notifications/unread-count  - cheap call for the bell badge.
async function unreadCount(req, res) {
  const count = await Notification.countDocuments({ user: req.user._id, isRead: false });
  res.json({ success: true, data: { unreadCount: count } });
}

// PUT /api/notifications/:id/read
async function markRead(req, res) {
  // Filtering by user too means someone else's notification is simply "not found".
  const notification = await Notification.findOneAndUpdate(
    { _id: req.params.id, user: req.user._id },
    { isRead: true },
    { new: true }
  );
  if (!notification) throw ApiError.notFound('Notification not found');
  res.json({ success: true, data: { notification } });
}

// PUT /api/notifications/read-all
async function markAllRead(req, res) {
  const result = await Notification.updateMany({ user: req.user._id, isRead: false }, { isRead: true });
  res.json({ success: true, data: { updated: result.modifiedCount } });
}

module.exports = { list, unreadCount, markRead, markAllRead };
