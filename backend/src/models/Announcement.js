const mongoose = require('mongoose');

const ANNOUNCEMENT_CATEGORIES = Object.freeze(['general', 'holiday', 'maintenance', 'meeting', 'important']);

// A company-wide notice posted by an admin or manager and visible to everyone.
const announcementSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 150 },
    message: { type: String, required: true, trim: true, maxlength: 3000 },
    category: { type: String, enum: ANNOUNCEMENT_CATEGORIES, default: 'general' },
    pinned: { type: Boolean, default: false }, // pinned posts stay at the top of the list
    author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

// Matches the list's sort: pinned first, then newest.
announcementSchema.index({ pinned: -1, createdAt: -1 });

announcementSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

const Announcement = mongoose.model('Announcement', announcementSchema);

module.exports = Announcement;
module.exports.ANNOUNCEMENT_CATEGORIES = ANNOUNCEMENT_CATEGORIES;
