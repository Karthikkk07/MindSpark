'use strict';

const mongoose = require('mongoose');

const deviceTokenSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    // The Firebase Cloud Messaging registration token of one app install.
    token: { type: String, required: true },
    platform: { type: String, enum: ['android'], default: 'android' },
  },
  { timestamps: true },
);

// A token belongs to one install, so it can belong to only one account.
deviceTokenSchema.index({ token: 1 }, { unique: true });
deviceTokenSchema.index({ user: 1, updatedAt: -1 });

module.exports = mongoose.model('DeviceToken', deviceTokenSchema);
