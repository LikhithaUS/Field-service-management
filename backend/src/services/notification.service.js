const Notification = require('../models/Notification');
const User = require('../models/User');
const { ROLES } = require('../utils/roles');

// Keep within the Notification schema limits so long titles (e.g. from announcements)
// are shortened instead of failing validation.
const clip = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

/**
 * Creates the same notification for each recipient.
 *
 * - `recipients`: user ids (ObjectIds or strings); duplicates and nulls are ignored.
 * - `actor`: the user who caused the event; they never get notified about their own action.
 *
 * A failed notification must never fail the action that triggered it (the task was still
 * assigned), so errors are logged and swallowed.
 */
async function notify(recipients, { actor, title, message = '', type = 'general', entityType = null, entityId = null }) {
  try {
    const actorId = actor ? String(actor._id || actor) : null;
    const ids = [...new Set(recipients.filter(Boolean).map((r) => String(r._id || r)))].filter((id) => id !== actorId);
    if (!ids.length) return [];
    return await Notification.insertMany(ids.map((user) => ({ user, title: clip(title, 120), message: clip(message, 500), type, entityType, entityId })));
  } catch (err) {
    console.error('Failed to create notifications:', err);
    return [];
  }
}

/** Active users who can review `requester`'s leave: admins always, managers for employees. */
async function leaveReviewers(requester) {
  const roles = requester.role === ROLES.EMPLOYEE ? [ROLES.ADMIN, ROLES.MANAGER] : [ROLES.ADMIN];
  return User.find({ role: { $in: roles }, isActive: true }).distinct('_id');
}

module.exports = { notify, leaveReviewers };
