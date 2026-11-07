
'use strict';

const dns = require('node:dns');
dns.setServers(['1.1.1.1', '8.8.8.8']);

const mongoose = require('mongoose');
const { loadEnv } = require('./config/env');
const { connectDb } = require('./config/db');
const { createApp } = require('./app');
const { createLogger } = require('./utils/logger');

async function main() {
  const env = loadEnv();
  const logger = createLogger(env.LOG_LEVEL);

  if (!env.MONGODB_URI) {
    logger.fatal('MONGODB_URI is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }

  await connectDb(env.MONGODB_URI);
  logger.info('Connected to MongoDB');

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
