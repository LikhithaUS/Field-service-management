const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { config } = require('../config/env');
const { ALL_ROLES, ROLES } = require('../utils/roles');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    // select: false -> the hash is never returned by queries unless explicitly requested.
    password: { type: String, required: true, minlength: 8, select: false },
    role: { type: String, enum: ALL_ROLES, default: ROLES.EMPLOYEE },
    // Links the login account to an employee record (added in the Employee module).
    employeeId: { type: String, trim: true, unique: true, sparse: true },
    isActive: { type: Boolean, default: true },
    // Incremented on logout / password change; tokens carrying an older version are rejected.
    tokenVersion: { type: Number, default: 0, select: false },
    // One-time code for password reset / first-time account setup. Only the HMAC hash is stored.
    resetCodeHash: { type: String, select: false },
    resetCodeExpiresAt: { type: Date, select: false },
    resetCodeAttempts: { type: Number, default: 0, select: false },
  },
  { timestamps: true }
);

// Hash the password whenever it is set or changed. Plain text is never stored.
userSchema.pre('save', async function hashPassword() {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, config.bcryptSaltRounds);
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

// Strip internal fields whenever a user is sent as JSON.
userSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    delete ret.password;
    delete ret.tokenVersion;
    delete ret.resetCodeHash;
    delete ret.resetCodeExpiresAt;
    delete ret.resetCodeAttempts;
    return ret;
  },
});

module.exports = mongoose.model('User', userSchema);
