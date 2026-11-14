'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { rateLimit } = require('express-rate-limit');
const pinoHttp = require('pino-http');
const mongoose = require('mongoose');

const { loadEnv } = require('./config/env');
const { createLogger } = require('./utils/logger');
const { createAuthService } = require('./services/authService');
const quotesRouter = require('./routes/quotes');
const createAuthRouter = require('./routes/auth');
const createUsersRouter = require('./routes/users');
const createFavoritesRouter = require('./routes/favorites');
const createGoalsRouter = require('./routes/goals');
const createAiRouter = require('./routes/ai');
const { createAiService } = require('./services/aiService');
const { createGeminiClient } = require('./services/geminiClient');
const { notFound, errorHandler } = require('./middleware/errorHandler');

/** Builds the Express app. It does not listen or connect to the database. */
function createApp(overrides = {}) {
  const { aiGenerate, ...envOverrides } = overrides;
  const env = { ...loadEnv(), ...envOverrides };
  if (!env.JWT_SECRET) {
    throw new Error('JWT_SECRET is not set (at least 32 characters, see .env.example)');
  }
  const logger = createLogger(env.LOG_LEVEL);
  const auth = createAuthService(env);
  const generate = aiGenerate || (env.GEMINI_API_KEY ? createGeminiClient(env) : null);
  const ai = createAiService(env, generate, logger);
  const app = express();
  // Behind a host's proxy the client address comes from X-Forwarded-For;
  // without this every user would share one rate limit.
  app.set('trust proxy', env.TRUST_PROXY);

  app.use(pinoHttp({ logger }));
  app.use(helmet());
  if (env.CORS_ORIGIN) {
    app.use(
      cors({ origin: env.CORS_ORIGIN.split(',').map((origin) => origin.trim()) }),
    );
  }
  app.use(express.json({ limit: '10kb' }));

  const limiter = (limit, message) =>
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      message: { error: { code: 'rate_limited', message } },
    });

  app.use('/api', limiter(env.RATE_LIMIT_MAX, 'Too many requests, please try again later'));
  const authLimiter = limiter(env.AUTH_RATE_LIMIT_MAX, 'Too many attempts, please try again later');

  app.get('/api/health', (_req, res) => {
    res.json({
      status: 'ok',
      db: mongoose.connection.readyState === 1 ? 'up' : 'down',
      uptimeSeconds: Math.round(process.uptime()),
    });
  });
  app.use('/api/quotes', quotesRouter);
  app.use('/api/auth', createAuthRouter(auth, authLimiter));
  app.use('/api/users', createUsersRouter(auth));
  app.use('/api/favorites', createFavoritesRouter(auth));
  app.use('/api/goals', createGoalsRouter(auth));
  app.use('/api/ai', createAiRouter(auth, ai));

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
