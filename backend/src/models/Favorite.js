'use strict';

const mongoose = require('mongoose');

const favoriteSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    // The quote's public id (for example q001), as used by the app.
    quoteId: { type: String, required: true, trim: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// One favourite per user and quote: duplicates are impossible.
favoriteSchema.index({ user: 1, quoteId: 1 }, { unique: true });
favoriteSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('Favorite', favoriteSchema);
