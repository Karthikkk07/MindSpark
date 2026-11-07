'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { rateLimit } = require('express-rate-limit');
const pinoHttp = require('pino-http');
const mongoose = require('mongoose');

const { loadEnv } = require('./config/env');
const { createLogger } = require('./utils/logger');
const quotesRouter = require('./routes/quotes');
const { notFound, errorHandler } = require('./middleware/errorHandler');

/** Builds the Express app. It does not listen or connect to the database. */
function createApp(overrides = {}) {
  const env = { ...loadEnv(), ...overrides };
  const logger = createLogger(env.LOG_LEVEL);
  const app = express();

  app.use(pinoHttp({ logger }));
  app.use(helmet());
  if (env.CORS_ORIGIN) {
    app.use(
      cors({ origin: env.CORS_ORIGIN.split(',').map((origin) => origin.trim()) }),
    );
  }
  app.use(express.json({ limit: '10kb' }));

  app.use(
    '/api',
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: env.RATE_LIMIT_MAX,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      message: {
        error: {
          code: 'rate_limited',
          message: 'Too many requests, please try again later',
        },
      },
    }),
  );

  app.get('/api/health', (_req, res) => {
    res.json({
      status: 'ok',
      db: mongoose.connection.readyState === 1 ? 'up' : 'down',
      uptimeSeconds: Math.round(process.uptime()),
    });
  });
  app.use('/api/quotes', quotesRouter);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
