'use strict';

const { z } = require('zod');

// FCM registration tokens are long opaque strings.
const tokenBody = z
  .object({ token: z.string().trim().min(20).max(4096) })
  .strict();

// A short wait lets the user leave the app before the test push arrives.
const testBody = z
  .object({ delaySeconds: z.number().int().min(0).max(30).optional() })
  .strict();

module.exports = { tokenBody, testBody };
