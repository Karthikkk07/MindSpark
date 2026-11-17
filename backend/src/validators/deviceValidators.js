'use strict';

const { z } = require('zod');

// FCM registration tokens are long opaque strings.
const tokenBody = z
  .object({ token: z.string().trim().min(20).max(4096) })
  .strict();

module.exports = { tokenBody };
