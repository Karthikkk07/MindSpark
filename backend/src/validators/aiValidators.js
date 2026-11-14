'use strict';

const { z } = require('zod');
const CATEGORIES = require('../models/categories');

const suggestBody = z
  .object({
    title: z.string().trim().min(1).max(100),
    description: z.string().trim().max(500).default(''),
    category: z.enum(CATEGORIES).optional(),
  })
  .strict();

const count = z.number().int().min(0).max(3650);

const encourageBody = z
  .object({
    title: z.string().trim().min(1).max(100),
    category: z.enum(CATEGORIES).optional(),
    currentStreak: count,
    longestStreak: count,
    checkInsLast14Days: z.number().int().min(0).max(14),
    milestonesDone: z.number().int().min(0).max(20),
    milestonesTotal: z.number().int().min(0).max(20),
    checkedInToday: z.boolean().default(false),
  })
  .strict()
  .refine((value) => value.milestonesDone <= value.milestonesTotal, {
    message: 'milestonesDone cannot exceed milestonesTotal',
    path: ['milestonesDone'],
  });

module.exports = { suggestBody, encourageBody };
