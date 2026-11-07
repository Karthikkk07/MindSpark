'use strict';

const mongoose = require('mongoose');
const CATEGORIES = require('./categories');

const quoteSchema = new mongoose.Schema(
  {
    // Same id the Flutter app uses (for example q001).
    quoteId: { type: String, required: true, unique: true, trim: true },
    text: { type: String, required: true, trim: true, maxlength: 500 },
    textLength: { type: Number, default: 0 },
    author: { type: String, required: true, trim: true, maxlength: 100 },
    category: { type: String, required: true, enum: CATEGORIES },
    tags: { type: [String], default: [] },
    source: { type: String, default: '' },
    license: { type: String, required: true },
    // Only published quotes are returned by the API.
    status: {
      type: String,
      enum: ['published', 'pending', 'hidden'],
      default: 'published',
    },
    order: { type: Number, default: 0 },
  },
  { timestamps: true },
);

quoteSchema.index({ status: 1, order: 1 });
quoteSchema.index({ status: 1, category: 1, order: 1 });

quoteSchema.pre('validate', function () {
  this.textLength = this.text ? this.text.length : 0;
});

module.exports = mongoose.model('Quote', quoteSchema);
