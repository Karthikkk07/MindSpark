
'use strict';

const dns = require('node:dns');
dns.setServers(['1.1.1.1', '8.8.8.8']);

// Loads assets/data/quotes.json into MongoDB. Safe to run repeatedly.
const fs = require('node:fs');
const path = require('node:path');
const mongoose = require('mongoose');
const { loadEnv } = require('../src/config/env');
const { connectDb } = require('../src/config/db');
const Quote = require('../src/models/Quote');

async function main() {
  const env = loadEnv();
  if (!env.MONGODB_URI) throw new Error('MONGODB_URI is not set (see .env.example)');

  const file = path.resolve(__dirname, '../../assets/data/quotes.json');
  const { quotes } = JSON.parse(fs.readFileSync(file, 'utf8'));

  await connectDb(env.MONGODB_URI);
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
  console.log(
    `Seed finished: ${result.upsertedCount} inserted, ${result.modifiedCount} updated, ${quotes.length} quotes in the file.`,
  );
  await mongoose.disconnect();
}
main().catch(async (err) => {
  console.error('MAIN ERROR:', err.message);

  if (err.reason?.servers) {
    for (const [address, server] of err.reason.servers) {
      console.log('\nSERVER:', address);
      console.log('ERROR:', server.error?.message);
    }
  }

  await mongoose.disconnect();
  process.exit(1);
});