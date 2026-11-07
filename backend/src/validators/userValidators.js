'use strict';

const { z } = require('zod');
const CATEGORIES = require('../models/categories');

const email = z.string().trim().toLowerCase().email().max(254);
const quoteId = z.string().regex(/^[A-Za-z0-9_-]{1,40}$/);

// bcrypt only uses the first 72 bytes, so longer passwords are rejected.
const registerBody = z
  .object({
    name: z.string().trim().min(1).max(60),
    email,
    password: z.string().min(8).max(72),
  })
  .strict();

const loginBody = z
  .object({ email, password: z.string().min(1).max(72) })
  .strict();

const preferencesBody = z
  .object({
    interests: z.array(z.enum(CATEGORIES)).max(10).optional(),
    themeMode: z.enum(['system', 'light', 'dark']).optional(),
    reminderEnabled: z.boolean().optional(),
    reminderHour: z.number().int().min(0).max(23).optional(),
    reminderMinute: z.number().int().min(0).max(59).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field',
  });

const mergeBody = z
  .object({ quoteIds: z.array(quoteId).max(100) })
  .strict();

module.exports = { registerBody, loginBody, preferencesBody, mergeBody };
