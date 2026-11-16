const mongoose = require('mongoose');

const NOTIFICATION_TYPES = Object.freeze([
  'task_assigned',
  'task_completed',
  'task_comment',
  'leave_requested',
  'leave_decision',
  'general',
]);
// What a notification points at, so the app can open it when tapped.
const ENTITY_TYPES = Object.freeze(['task', 'leave']);

// An in-app message for one user. Created by other modules through notification.service.js.
const notificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // recipient
    title: { type: String, required: true, trim: true, maxlength: 120 },
    message: { type: String, trim: true, maxlength: 500, default: '' },
    type: { type: String, enum: NOTIFICATION_TYPES, default: 'general' },
    entityType: { type: String, enum: [...ENTITY_TYPES, null], default: null },
    entityId: { type: mongoose.Schema.Types.ObjectId, default: null },
    isRead: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// "My notifications, newest first" and the unread count.
notificationSchema.index({ user: 1, createdAt: -1 });
notificationSchema.index({ user: 1, isRead: 1 });

notificationSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
module.exports.NOTIFICATION_TYPES = NOTIFICATION_TYPES;
module.exports.ENTITY_TYPES = ENTITY_TYPES;
