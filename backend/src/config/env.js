'use strict';

const path = require('node:path');
const dotenv = require('dotenv');
const { z } = require('zod');

dotenv.config({ path: path.resolve(__dirname, '../../.env'), quiet: true });

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  MONGODB_URI: z.string().min(1).optional(),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  CORS_ORIGIN: z.string().optional(),
  RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(100),
  AUTH_RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(20),
  JWT_SECRET: z.string().min(32, 'must be at least 32 characters').optional(),
  JWT_EXPIRES_IN: z.string().min(1).default('7d'),
  BCRYPT_ROUNDS: z.coerce.number().int().min(4).max(15).default(12),
  // How many reverse proxies sit in front of the API (1 on Render and similar hosts).
  TRUST_PROXY: z.coerce.number().int().min(0).max(5).default(0),
  GEMINI_API_KEY: z.string().min(1).optional(),
  GEMINI_MODEL: z.string().min(1).default('gemini-3.1-flash-lite'),
  AI_DAILY_LIMIT: z.coerce.number().int().min(1).default(10),
  AI_TIMEOUT_MS: z.coerce.number().int().min(1000).default(30000),
});

/** Validates configuration and fails fast with a clear message. */
function loadEnv(source = process.env) {
  // Empty values (as in .env.example) count as "not set".
  const cleaned = Object.fromEntries(
    Object.entries(source).filter(([, value]) => value !== ''),
  );
  const parsed = schema.safeParse(cleaned);
  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join('; ');
    throw new Error(`Invalid environment configuration: ${details}`);
  }
  return parsed.data;
}

module.exports = { loadEnv };
