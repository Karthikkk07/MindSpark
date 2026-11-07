'use strict';

const Favorite = require('../models/Favorite');
const Quote = require('../models/Quote');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const { idParam } = require('../validators/quoteValidators');
const { mergeBody } = require('../validators/userValidators');
const { toPublic } = require('./quotesController');

/** The user's favourite quotes, newest first. */
async function buildList(userId) {
  const favorites = await Favorite.find({ user: userId })
    .sort({ createdAt: -1, _id: -1 })
    .lean();
  const quotes = await Quote.find({
    quoteId: { $in: favorites.map((favorite) => favorite.quoteId) },
    status: 'published',
  }).lean();
  const byId = new Map(quotes.map((quote) => [quote.quoteId, quote]));
  return favorites
    .map((favorite) => byId.get(favorite.quoteId))
    .filter(Boolean)
    .map(toPublic);
}

/** Adds a favourite. Returns true if it was new. */
async function addFavorite(userId, quoteId) {
  try {
    const result = await Favorite.updateOne(
      { user: userId, quoteId },
      { $setOnInsert: { quoteId } },
      { upsert: true },
    );
    return result.upsertedCount > 0;
  } catch (err) {
    if (err && err.code === 11000) return false; // lost a race: already saved
    throw err;
  }
}

async function list(req, res) {
  res.json({ data: await buildList(req.userId) });
}

async function add(req, res) {
  const { id } = parse(idParam, { id: req.params.quoteId });
  if (!(await Quote.exists({ quoteId: id, status: 'published' }))) {
    throw new AppError(404, 'not_found', 'Quote not found');
  }
  const created = await addFavorite(req.userId, id);
  res.status(created ? 201 : 200).json({ data: { quoteId: id, favorited: true } });
}

async function remove(req, res) {
  const { id } = parse(idParam, { id: req.params.quoteId });
  await Favorite.deleteOne({ user: req.userId, quoteId: id });
  res.status(204).end();
}

/**
 * Merges a guest's favourites (newest first) into the account.
 * Unknown ids are ignored. Returns the full list.
 */
async function merge(req, res) {
  const { quoteIds } = parse(mergeBody, req.body);
  const unique = [...new Set(quoteIds)];
  const known = await Quote.find({
    quoteId: { $in: unique },
    status: 'published',
  }).select('quoteId').lean();
  const knownIds = new Set(known.map((quote) => quote.quoteId));

  // Oldest first, so the guest's newest favourite ends up newest on the server.
  for (const quoteId of unique.filter((id) => knownIds.has(id)).reverse()) {
    await addFavorite(req.userId, quoteId);
  }
  res.json({ data: await buildList(req.userId) });
}

module.exports = { list, add, remove, merge };
