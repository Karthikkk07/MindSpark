'use strict';

const mongoose = require('mongoose');
const CATEGORIES = require('./categories');

const milestoneSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 100 },
  done: { type: Boolean, default: false },
  doneAt: { type: Date, default: null },
});

const goalSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, default: '', trim: true, maxlength: 500 },
    category: { type: String, required: true, enum: CATEGORIES },
    // A calendar date (YYYY-MM-DD), so time zones cannot shift it.
    targetDate: { type: String, default: null, match: /^\d{4}-\d{2}-\d{2}$/ },
    status: { type: String, enum: ['active', 'completed', 'archived'], default: 'active' },
    completedAt: { type: Date, default: null },
    // What to do each day, for example "Read for 20 minutes".
    dailyAction: { type: String, default: '', trim: true, maxlength: 100 },
    milestones: { type: [milestoneSchema], default: [] },
    // Days the daily action was done, as calendar dates (YYYY-MM-DD).
    checkIns: { type: [String], default: [] },
    // When the goal was last changed by a client; decides who wins in sync.
    clientUpdatedAt: { type: Date, default: Date.now },
  },
  { timestamps: true },
);

goalSchema.index({ user: 1, status: 1, createdAt: -1 });

module.exports = mongoose.model('Goal', goalSchema);
