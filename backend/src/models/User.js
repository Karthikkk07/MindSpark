'use strict';

const mongoose = require('mongoose');
const CATEGORIES = require('./categories');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, minlength: 1, maxlength: 60 },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      maxlength: 254,
    },
    // Never returned by queries unless explicitly selected.
    passwordHash: { type: String, required: true, select: false },
    preferences: {
      interests: { type: [{ type: String, enum: CATEGORIES }], default: [] },
      themeMode: { type: String, enum: ['system', 'light', 'dark'], default: 'system' },
      reminderEnabled: { type: Boolean, default: false },
      reminderHour: { type: Number, min: 0, max: 23, default: 8 },
      reminderMinute: { type: Number, min: 0, max: 59, default: 0 },
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model('User', userSchema);
