'use strict';

const { z } = require('zod');
const CATEGORIES = require('../models/categories');
const { isValidDateString } = require('../services/streaks');

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Use the format YYYY-MM-DD')
  .refine(isValidDateString, 'Not a real calendar date');

const objectId = z.string().regex(/^[a-fA-F0-9]{24}$/, 'Invalid id');

const milestone = z
  .object({
    id: objectId.optional(),
    title: z.string().trim().min(1).max(100),
    done: z.boolean().default(false),
  })
  .strict();

const createBody = z
  .object({
    title: z.string().trim().min(1).max(100),
    description: z.string().trim().max(500).default(''),
    category: z.enum(CATEGORIES),
    targetDate: dateString.nullable().optional(),
    dailyAction: z.string().trim().max(100).default(''),
    milestones: z.array(milestone).max(20).default([]),
  })
  .strict();

const updateBody = z
  .object({
    title: z.string().trim().min(1).max(100).optional(),
    description: z.string().trim().max(500).optional(),
    category: z.enum(CATEGORIES).optional(),
    targetDate: dateString.nullable().optional(),
    dailyAction: z.string().trim().max(100).optional(),
    status: z.enum(['active', 'completed', 'archived']).optional(),
    milestones: z.array(milestone).max(20).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field',
  });

const listQuery = z.object({
  status: z.enum(['active', 'completed', 'archived']).optional(),
});

const todayQuery = z.object({ today: dateString.optional() });
const idParam = z.object({ id: objectId });
const checkInBody = z.object({ date: dateString }).strict();
const checkInParams = z.object({ id: objectId, date: dateString });

module.exports = {
  createBody,
  updateBody,
  listQuery,
  todayQuery,
  idParam,
  checkInBody,
  checkInParams,
};
