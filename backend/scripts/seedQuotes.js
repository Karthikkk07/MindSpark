'use strict';

// Loads assets/data/quotes.json into MongoDB. Safe to run repeatedly.
const mongoose = require('mongoose');
const { loadEnv } = require('../src/config/env');
const { connectDb } = require('../src/config/db');
const { seedQuotes } = require('../src/services/quoteSeed');

async function main() {
  const env = loadEnv();
  if (!env.MONGODB_URI) throw new Error('MONGODB_URI is not set (see .env.example)');

  await connectDb(env.MONGODB_URI);
  const result = await seedQuotes();
  console.log(
    `Seed finished: ${result.inserted} inserted, ${result.updated} updated, ${result.total} quotes in the file.`,
  );
  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error(err.message);
  await mongoose.disconnect();
  process.exit(1);
});
