'use strict';

// Runs the API on a temporary in-memory MongoDB with the app's quotes loaded.
// Data disappears when you stop it. Local development only.
const fs = require('node:fs');
const path = require('node:path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'local-dev-secret-local-dev-secret-0123456789';
const { createApp } = require('../src/app');
const Quote = require('../src/models/Quote');
const User = require('../src/models/User');
const Favorite = require('../src/models/Favorite');
const Goal = require('../src/models/Goal');
const AiUsage = require('../src/models/AiUsage');

async function main() {
  const mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  // The AI daily limit depends on AiUsage's unique index, so build it up front.
  await Promise.all([Quote.init(), User.init(), Favorite.init(), Goal.init(), AiUsage.init()]);

  const file = path.resolve(__dirname, '../../assets/data/quotes.json');
  const { quotes } = JSON.parse(fs.readFileSync(file, 'utf8'));
  await Quote.insertMany(
    quotes.map((quote, index) => ({
      quoteId: quote.id,
      text: quote.text,
      author: quote.author,
      category: quote.category,
      tags: quote.tags,
      source: quote.source,
      license: quote.license,
      order: index,
    })),
  );

  const port = Number(process.env.PORT) || 3000;
  const app = createApp({ LOG_LEVEL: 'warn', RATE_LIMIT_MAX: 1000, AUTH_RATE_LIMIT_MAX: 100 });
  const server = app.listen(port, () => {
    console.log(`Local API on http://localhost:${port}/api (in-memory database, ${quotes.length} quotes)`);
  });

  const stop = async () => {
    server.close();
    await mongoose.disconnect();
    await mongod.stop();
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
