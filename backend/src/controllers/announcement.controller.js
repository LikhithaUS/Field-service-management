const Announcement = require('../models/Announcement');
const Notification = require('../models/Notification');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { ROLES } = require('../utils/roles');
const { parsePagination, paginationMeta, escapeRegex } = require('../utils/query');
const { notify } = require('../services/notification.service');

const AUTHOR_FIELDS = 'name email role employeeId';
const EDITABLE_FIELDS = ['title', 'message', 'category', 'pinned'];

// Admins manage every announcement; managers only the ones they posted.
function assertCanManage(announcement, user) {
  if (user.role === ROLES.ADMIN) return;
  const authorId = announcement.author._id || announcement.author;
  if (!authorId.equals(user._id)) throw ApiError.forbidden('You can only change announcements you posted');
}

const preview = (text) => (text.length > 140 ? `${text.slice(0, 139)}…` : text);

// GET /api/announcements?category=&search=&page=&limit=  (everyone)
async function list(req, res) {
  const { category, search } = req.query;
  const filter = {};
  if (category) filter.category = category;
  if (search && search.trim()) {
    const rx = new RegExp(escapeRegex(search.trim()), 'i');
    filter.$or = [{ title: rx }, { message: rx }];
  }

  const paging = parsePagination(req.query);
  const [items, total] = await Promise.all([
    Announcement.find(filter)
      .sort({ pinned: -1, createdAt: -1 })
      .skip(paging.skip)
      .limit(paging.limit)
      .populate('author', AUTHOR_FIELDS),
    Announcement.countDocuments(filter),
  ]);

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total) } });
}

// GET /api/announcements/:id
async function getOne(req, res) {
  const announcement = await Announcement.findById(req.params.id).populate('author', AUTHOR_FIELDS);
  if (!announcement) throw ApiError.notFound('Announcement not found');
  res.json({ success: true, data: { announcement } });
}

// POST /api/announcements  (admin, manager) - notifies every active user.
async function create(req, res) {
  const { title, message, category, pinned } = req.body;
  const announcement = await Announcement.create({ title, message, category, pinned, author: req.user._id });

  const everyone = await User.find({ isActive: true }).distinct('_id');
  await notify(everyone, {
    actor: req.user,
    title: `Announcement: ${announcement.title}`,
    message: preview(announcement.message),
    type: 'announcement',
    entityType: 'announcement',
    entityId: announcement._id,
  });

  await announcement.populate('author', AUTHOR_FIELDS);
  res.status(201).json({ success: true, data: { announcement } });
}

// PUT /api/announcements/:id  (admin, or the manager who posted it). Edits don't re-notify.
async function update(req, res) {
  const announcement = await Announcement.findById(req.params.id);
  if (!announcement) throw ApiError.notFound('Announcement not found');
  assertCanManage(announcement, req.user);

  for (const field of EDITABLE_FIELDS) {
    if (req.body[field] !== undefined) announcement[field] = req.body[field];
  }
  await announcement.save();

  await announcement.populate('author', AUTHOR_FIELDS);
  res.json({ success: true, data: { announcement } });
}

// DELETE /api/announcements/:id  (admin, or the manager who posted it)
// Also removes its notifications so nobody taps through to a deleted post.
async function remove(req, res) {
  const announcement = await Announcement.findById(req.params.id);
  if (!announcement) throw ApiError.notFound('Announcement not found');
  assertCanManage(announcement, req.user);

  await Promise.all([
    announcement.deleteOne(),
    Notification.deleteMany({ entityType: 'announcement', entityId: announcement._id }),
  ]);
  res.json({ success: true, message: 'Announcement deleted' });
}

module.exports = { list, getOne, create, update, remove };
