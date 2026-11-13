'use strict';

const { z } = require('zod');
const CATEGORIES = require('../models/categories');
const { isValidDateString, dayNumber, utcToday } = require('../services/streaks');

const STATUSES = ['active', 'completed', 'archived'];
const EARLIEST_CHECK_IN = '2020-01-01';

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Use the format YYYY-MM-DD')
  .refine(isValidDateString, 'Not a real calendar date');

/** Check-in history: from 2020 up to one day after the server date. */
const checkInDate = dateString.refine(
  (value) =>
    dayNumber(value) >= dayNumber(EARLIEST_CHECK_IN) &&
    dayNumber(value) <= dayNumber(utcToday()) + 1,
  'Date is outside the allowed range',
);

/** A client change time, not more than a day ahead of the server clock. */
const timestamp = z
  .string()
  .refine((value) => !Number.isNaN(Date.parse(value)), 'Invalid date-time')
  .refine((value) => Date.parse(value) <= Date.now() + 24 * 60 * 60 * 1000, 'Time is in the future');

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
    status: z.enum(STATUSES).default('active'),
    milestones: z.array(milestone).max(20).default([]),
    checkIns: z.array(checkInDate).max(3650).default([]),
    clientUpdatedAt: timestamp.optional(),
  })
  .strict();

/** Replaces a whole goal. Used by sync. */
const replaceBody = z
  .object({
    title: z.string().trim().min(1).max(100),
    description: z.string().trim().max(500).default(''),
    category: z.enum(CATEGORIES),
    targetDate: dateString.nullable().optional(),
    dailyAction: z.string().trim().max(100).default(''),
    status: z.enum(STATUSES),
    milestones: z.array(milestone).max(20).default([]),
    checkIns: z.array(checkInDate).max(3650).default([]),
    clientUpdatedAt: timestamp,
  })
  .strict();

const updateBody = z
  .object({
    title: z.string().trim().min(1).max(100).optional(),
    description: z.string().trim().max(500).optional(),
    category: z.enum(CATEGORIES).optional(),
    targetDate: dateString.nullable().optional(),
    dailyAction: z.string().trim().max(100).optional(),
    status: z.enum(STATUSES).optional(),
    milestones: z.array(milestone).max(20).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field',
  });

const listQuery = z.object({ status: z.enum(STATUSES).optional() });
const todayQuery = z.object({ today: dateString.optional() });
const idParam = z.object({ id: objectId });
const checkInBody = z.object({ date: dateString }).strict();
const checkInParams = z.object({ id: objectId, date: dateString });

module.exports = {
  createBody,
  replaceBody,
  updateBody,
  listQuery,
  todayQuery,
  idParam,
  checkInBody,
  checkInParams,
};
