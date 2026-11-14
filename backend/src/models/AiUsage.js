'use strict';

const mongoose = require('mongoose');

/** How many AI requests a user has made on one UTC day. */
const aiUsageSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  day: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
  count: { type: Number, required: true, default: 0, min: 0 },
  // Old counters are removed by the database after about two days.
  createdAt: { type: Date, default: Date.now, expires: 2 * 24 * 60 * 60 },
});

aiUsageSchema.index({ user: 1, day: 1 }, { unique: true });

module.exports = mongoose.model('AiUsage', aiUsageSchema);
