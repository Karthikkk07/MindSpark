'use strict';

const mongoose = require('mongoose');
const { loadEnv } = require('./config/env');
const { connectDb } = require('./config/db');
const { createApp } = require('./app');
const { createLogger } = require('./utils/logger');
const { seedQuotesIfEmpty } = require('./services/quoteSeed');

async function main() {
  const env = loadEnv();
  const logger = createLogger(env.LOG_LEVEL);

  if (!env.MONGODB_URI) {
    logger.fatal('MONGODB_URI is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }

  await connectDb(env.MONGODB_URI);
  logger.info('Connected to MongoDB');

  // A new database starts with the app's quotes, so no manual seeding is needed.
  const seeded = await seedQuotesIfEmpty();
  if (seeded) logger.info(seeded, 'Loaded the quotes into an empty database');

  const server = createApp().listen(env.PORT, () => {
    logger.info({ port: env.PORT }, 'API listening');
  });

  const shutdown = (signal) => {
    logger.info({ signal }, 'Shutting down');
    server.close(async () => {
      await mongoose.disconnect();
      process.exit(0);
    });
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
