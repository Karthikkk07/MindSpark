'use strict';

const fs = require('node:fs');
const path = require('node:path');
const Quote = require('../models/Quote');

const DEFAULT_FILE = path.resolve(__dirname, '../../../assets/data/quotes.json');

/** Loads the app's quotes into MongoDB. Safe to run repeatedly. */
async function seedQuotes(file = DEFAULT_FILE) {
  const { quotes } = JSON.parse(fs.readFileSync(file, 'utf8'));
  await Quote.init();

  const operations = quotes.map((quote, index) => ({
    updateOne: {
      filter: { quoteId: quote.id },
      update: {
        $set: {
          quoteId: quote.id,
          text: quote.text,
          textLength: quote.text.length,
          author: quote.author,
          category: quote.category,
          tags: quote.tags,
          source: quote.source,
          license: quote.license,
          order: index,
        },
        $setOnInsert: { status: 'published' },
      },
      upsert: true,
    },
  }));

  const result = await Quote.bulkWrite(operations);
  return {
    inserted: result.upsertedCount,
    updated: result.modifiedCount,
    total: quotes.length,
  };
}

/** Tops up the database when it has fewer quotes than the file (new host or a larger quote set). */
async function seedMissingQuotes(file = DEFAULT_FILE) {
  const { quotes } = JSON.parse(fs.readFileSync(file, 'utf8'));
  if ((await Quote.estimatedDocumentCount()) >= quotes.length) return null;
  return seedQuotes(file);
}

module.exports = { seedQuotes, seedMissingQuotes };
