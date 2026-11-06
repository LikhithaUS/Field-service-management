const mongoose = require('mongoose');

const departmentSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    description: { type: String, trim: true, maxlength: 300, default: '' },
  },
  { timestamps: true }
);

// Unique regardless of case: "Sales" and "sales" can't both exist.
departmentSchema.index({ name: 1 }, { unique: true, collation: { locale: 'en', strength: 2 } });

departmentSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('Department', departmentSchema);
