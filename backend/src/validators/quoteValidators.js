'use strict';

const { z } = require('zod');
const CATEGORIES = require('../models/categories');

const category = z.enum(CATEGORIES);

const listQuery = z.object({
  search: z.string().trim().max(50).optional(),
  category: category.optional(),
  sort: z.enum(['curated', 'az', 'shortest']).default('curated'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const randomQuery = z.object({ category: category.optional() });
const idParam = z.object({ id: z.string().regex(/^[A-Za-z0-9_-]{1,40}$/) });
const categoryParam = z.object({ category });

module.exports = { listQuery, randomQuery, idParam, categoryParam };
