const Task = require('../models/Task');
const Comment = require('../models/Comment');
const Counter = require('../models/Counter');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { ROLES } = require('../utils/roles');
const { parsePagination, paginationMeta, escapeRegex } = require('../utils/query');
const { notify } = require('../services/notification.service');

const { OPEN_STATUSES } = Task;

const SORTS = {
  createdAt: { createdAt: 1 },
  '-createdAt': { createdAt: -1 },
  dueDate: { dueDate: 1, createdAt: -1 },
  '-dueDate': { dueDate: -1, createdAt: -1 },
  title: { title: 1 },
  '-title': { title: -1 },
};

const EDITABLE_FIELDS = ['title', 'description', 'location', 'assignedTo', 'priority', 'status', 'dueDate'];
// What an assignee (employee) may set the status to. Cancelling is a manager decision.
const ASSIGNEE_STATUSES = ['pending', 'in_progress', 'completed'];
const PERSON_FIELDS = 'name email role employeeId';
const PEOPLE = [
  { path: 'assignedTo', select: PERSON_FIELDS },
  { path: 'assignedBy', select: PERSON_FIELDS },
];

const isStaff = (user) => user.role === ROLES.ADMIN || user.role === ROLES.MANAGER;
const isAssignee = (task, user) => {
  const id = task.assignedTo._id || task.assignedTo; // populated or not
  return id.equals(user._id);
};

function populated(query) {
  return query.populate(PEOPLE);
}

async function nextTaskNumber() {
  const seq = await Counter.next('task');
  return `TSK-${String(seq).padStart(4, '0')}`;
}

// Midnight UTC today. Due dates are stored as midnight UTC, so a task due today is not overdue yet.
function startOfTodayUtc() {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

async function assertAssignable(userId) {
  const user = await User.findById(userId);
  if (!user || !user.isActive) throw ApiError.badRequest('Assignee not found or inactive');
}

// Staff see every task; employees only see tasks assigned to them. A task the viewer may not
// see is reported as "not found" so its existence isn't revealed.
async function findVisibleTask(req, { populate = false } = {}) {
  const query = Task.findById(req.params.id);
  const task = await (populate ? populated(query) : query);
  if (!task || (!isStaff(req.user) && !isAssignee(task, req.user))) throw ApiError.notFound('Task not found');
  return task;
}

// GET /api/tasks?search=&status=&priority=&assignedTo=&mine=&overdue=&sort=&page=&limit=
async function list(req, res) {
  const { search, status, priority, assignedTo, mine, overdue, sort } = req.query;
  const filter = {};

  if (!isStaff(req.user) || mine === 'true') filter.assignedTo = req.user._id;
  else if (assignedTo) filter.assignedTo = assignedTo;

  if (search && search.trim()) {
    const rx = new RegExp(escapeRegex(search.trim()), 'i');
    filter.$or = [{ title: rx }, { taskNumber: rx }, { description: rx }, { location: rx }];
  }
  if (priority) filter.priority = priority;
  if (overdue === 'true') {
    filter.dueDate = { $lt: startOfTodayUtc() };
    // A finished task is never overdue, so e.g. overdue + completed matches nothing.
    const statuses = status ? [status] : OPEN_STATUSES;
    filter.status = { $in: statuses.filter((s) => OPEN_STATUSES.includes(s)) };
  } else if (status) {
    filter.status = status;
  }

  const paging = parsePagination(req.query);
  const [items, total] = await Promise.all([
    populated(Task.find(filter))
      .collation({ locale: 'en' })
      .sort(SORTS[sort] || SORTS['-createdAt'])
      .skip(paging.skip)
      .limit(paging.limit),
    Task.countDocuments(filter),
  ]);

  res.json({ success: true, data: { items, pagination: paginationMeta(paging, total) } });
}

// GET /api/tasks/:id
async function getOne(req, res) {
  const task = await findVisibleTask(req, { populate: true });
  const commentCount = await Comment.countDocuments({ task: task._id });
  res.json({ success: true, data: { task: { ...task.toJSON(), commentCount } } });
}

// POST /api/tasks  (admin, manager)
async function create(req, res) {
  const { title, description, location, assignedTo, priority, status, dueDate } = req.body;
  await assertAssignable(assignedTo);

  const task = await Task.create({
    taskNumber: await nextTaskNumber(),
    title,
    description,
    location,
    assignedTo,
    assignedBy: req.user._id,
    priority,
    status,
    dueDate: dueDate || null,
  });

  await notify([task.assignedTo], {
    actor: req.user,
    title: 'New task assigned',
    message: `${req.user.name} assigned you ${task.taskNumber}: ${task.title}`,
    type: 'task_assigned',
    entityType: 'task',
    entityId: task._id,
  });

  await task.populate(PEOPLE);
  res.status(201).json({ success: true, data: { task: { ...task.toJSON(), commentCount: 0 } } });
}

// PUT /api/tasks/:id
// Staff can change anything. The assignee can only move the status between
// pending / in progress / completed, and can't touch a cancelled task.
async function update(req, res) {
  const task = await findVisibleTask(req);

  const updates = {};
  for (const field of EDITABLE_FIELDS) {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  }

  if (!isStaff(req.user)) {
    const other = Object.keys(updates).filter((f) => f !== 'status');
    if (other.length) throw ApiError.forbidden('You can only update the status of your tasks');
    if (updates.status !== undefined) {
      if (task.status === 'cancelled') throw ApiError.forbidden('This task was cancelled');
      if (!ASSIGNEE_STATUSES.includes(updates.status)) throw ApiError.forbidden('Only a manager can cancel a task');
    }
  }

  if (updates.dueDate !== undefined) updates.dueDate = updates.dueDate || null;
  if (updates.assignedTo !== undefined && !task.assignedTo.equals(updates.assignedTo)) {
    await assertAssignable(updates.assignedTo);
  }

  const previous = { assignedTo: task.assignedTo, status: task.status };
  task.set(updates);
  await task.save();
  await notifyTaskChanges(task, previous, req.user);

  await task.populate(PEOPLE);
  const commentCount = await Comment.countDocuments({ task: task._id });
  res.json({ success: true, data: { task: { ...task.toJSON(), commentCount } } });
}

const truncate = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

// Tell the new assignee about a reassignment, and the creator when the work is done.
async function notifyTaskChanges(task, previous, actor) {
  const link = { actor, entityType: 'task', entityId: task._id };
  if (!task.assignedTo.equals(previous.assignedTo)) {
    await notify([task.assignedTo], {
      ...link,
      title: 'Task assigned to you',
      message: `${actor.name} reassigned ${task.taskNumber}: ${task.title} to you`,
      type: 'task_assigned',
    });
  }
  if (task.status === 'completed' && previous.status !== 'completed') {
    await notify([task.assignedBy], {
      ...link,
      title: 'Task completed',
      message: `${actor.name} completed ${task.taskNumber}: ${task.title}`,
      type: 'task_completed',
    });
  }
}

// DELETE /api/tasks/:id  (admin, manager) - also removes the task's comments.
async function remove(req, res) {
  const task = await Task.findById(req.params.id);
  if (!task) throw ApiError.notFound('Task not found');
  await Promise.all([task.deleteOne(), Comment.deleteMany({ task: task._id })]);
  res.json({ success: true, message: 'Task deleted' });
}

// GET /api/tasks/:id/comments  - oldest first, like a chat thread.
async function listComments(req, res) {
  const task = await findVisibleTask(req);
  const items = await Comment.find({ task: task._id }).sort({ createdAt: 1 }).populate('user', PERSON_FIELDS);
  res.json({ success: true, data: { items } });
}

// POST /api/tasks/:id/comments
async function addComment(req, res) {
  const task = await findVisibleTask(req);
  const comment = await Comment.create({ task: task._id, user: req.user._id, message: req.body.message });
  // Both sides of the conversation hear about it (the commenter is skipped by notify).
  await notify([task.assignedTo, task.assignedBy], {
    actor: req.user,
    title: `New comment on ${task.taskNumber}`,
    message: `${req.user.name}: ${truncate(comment.message, 120)}`,
    type: 'task_comment',
    entityType: 'task',
    entityId: task._id,
  });
  await comment.populate('user', PERSON_FIELDS);
  res.status(201).json({ success: true, data: { comment } });
}

module.exports = { list, getOne, create, update, remove, listComments, addComment };
