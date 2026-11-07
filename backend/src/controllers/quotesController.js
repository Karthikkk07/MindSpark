'use strict';

const Quote = require('../models/Quote');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const validators = require('../validators/quoteValidators');

const PUBLISHED = { status: 'published' };

const toPublic = (quote) => ({
  id: quote.quoteId,
  text: quote.text,
  author: quote.author,
  category: quote.category,
  tags: quote.tags,
  source: quote.source,
  license: quote.license,
});

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

async function findQuotes({ search, category, sort, page, limit }) {
  const filter = { ...PUBLISHED };
  if (category) filter.category = category;
  if (search) {
    const pattern = new RegExp(escapeRegex(search), 'i');
    filter.$or = [{ text: pattern }, { author: pattern }, { tags: pattern }];
  }

  let sortSpec = { order: 1, quoteId: 1 };
  if (sort === 'az') sortSpec = { text: 1, quoteId: 1 };
  if (sort === 'shortest') sortSpec = { textLength: 1, quoteId: 1 };

  const [items, total] = await Promise.all([
    Quote.find(filter)
      .collation({ locale: 'en', strength: 2 })
      .sort(sortSpec)
      .skip((page - 1) * limit)
      .limit(limit)
      .lean(),
    Quote.countDocuments(filter),
  ]);

  return {
    data: items.map(toPublic),
    page,
    limit,
    total,
    totalPages: Math.ceil(total / limit),
  };
}

async function listQuotes(req, res) {
  res.json(await findQuotes(parse(validators.listQuery, req.query)));
}

async function listByCategory(req, res) {
  const { category } = parse(validators.categoryParam, req.params);
  const query = parse(validators.listQuery, { ...req.query, category });
  res.json(await findQuotes(query));
}

async function randomQuote(req, res) {
  const { category } = parse(validators.randomQuery, req.query);
  const filter = { ...PUBLISHED };
  if (category) filter.category = category;
  const [doc] = await Quote.aggregate([
    { $match: filter },
    { $sample: { size: 1 } },
  ]);
  if (!doc) throw new AppError(404, 'not_found', 'No quotes available');
  res.json({ data: toPublic(doc) });
}

async function listCategories(_req, res) {
  const rows = await Quote.aggregate([
    { $match: PUBLISHED },
    { $group: { _id: '$category', count: { $sum: 1 } } },
    { $sort: { _id: 1 } },
  ]);
  res.json({ data: rows.map((row) => ({ id: row._id, count: row.count })) });
}

async function getQuote(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const doc = await Quote.findOne({ ...PUBLISHED, quoteId: id }).lean();
  if (!doc) throw new AppError(404, 'not_found', 'Quote not found');
  res.json({ data: toPublic(doc) });
}

module.exports = {
  toPublic,
  listQuotes,
  listByCategory,
  randomQuote,
  listCategories,
  getQuote,
};
