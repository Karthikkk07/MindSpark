'use strict';

const Goal = require('../models/Goal');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const validators = require('../validators/goalValidators');
const { toPublicGoal } = require('../utils/goalSerializer');
const { dayNumber, utcToday } = require('../services/streaks');

const MAX_GOALS = 100;

const notFound = () => new AppError(404, 'not_found', 'Goal not found');

/** Every query is limited to the signed-in user's own goals. */
const owned = (req, id) => ({ _id: id, user: req.userId });

/** Client dates must be within a day of the server date (time zones). */
function assertNearServerDate(value, field) {
  if (Math.abs(dayNumber(value) - dayNumber(utcToday())) > 1) {
    throw new AppError(400, 'validation_error', 'Invalid request', [
      { path: field, message: 'Date must be within one day of the server date' },
    ]);
  }
}

/** The user's own calendar date, sent as ?today=YYYY-MM-DD (default: UTC). */
function resolveToday(query) {
  const { today } = parse(validators.todayQuery, query);
  if (!today) return utcToday();
  assertNearServerDate(today, 'today');
  return today;
}

/** Keeps the ids of existing milestones and stamps when they were completed. */
function mergeMilestones(existing, incoming) {
  const byId = new Map(existing.map((milestone) => [String(milestone._id), milestone]));
  return incoming.map((item) => {
    const old = item.id ? byId.get(item.id.toLowerCase()) : undefined;
    const doneAt = item.done ? (old && old.done && old.doneAt ? old.doneAt : new Date()) : null;
    const fields = { title: item.title, done: item.done, doneAt };
    return old ? { _id: old._id, ...fields } : fields;
  });
}

/** Changes the status and stamps or clears the completion time. */
function applyStatus(goal, status, at) {
  if (status === goal.status) return;
  goal.status = status;
  goal.completedAt = status === 'completed' ? at : null;
}

async function listGoals(req, res) {
  const { status } = parse(validators.listQuery, req.query);
  const today = resolveToday(req.query);
  const filter = { user: req.userId };
  if (status) filter.status = status;
  const goals = await Goal.find(filter).sort({ createdAt: -1, _id: -1 });
  res.json({ data: goals.map((goal) => toPublicGoal(goal, today)) });
}

async function createGoal(req, res) {
  const body = parse(validators.createBody, req.body);
  const today = resolveToday(req.query);
  if ((await Goal.countDocuments({ user: req.userId })) >= MAX_GOALS) {
    throw new AppError(409, 'limit_reached', `You can have at most ${MAX_GOALS} goals`);
  }
  const stamp = body.clientUpdatedAt ? new Date(body.clientUpdatedAt) : new Date();
  const goal = await Goal.create({
    user: req.userId,
    title: body.title,
    description: body.description,
    category: body.category,
    targetDate: body.targetDate ?? null,
    dailyAction: body.dailyAction,
    status: body.status,
    completedAt: body.status === 'completed' ? stamp : null,
    milestones: mergeMilestones([], body.milestones),
    checkIns: [...new Set(body.checkIns)].sort(),
    clientUpdatedAt: stamp,
  });
  res.status(201).json({ data: toPublicGoal(goal, today) });
}

async function getGoal(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const today = resolveToday(req.query);
  const goal = await Goal.findOne(owned(req, id));
  if (!goal) throw notFound();
  res.json({ data: toPublicGoal(goal, today) });
}

async function updateGoal(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const body = parse(validators.updateBody, req.body);
  const today = resolveToday(req.query);
  const goal = await Goal.findOne(owned(req, id));
  if (!goal) throw notFound();

  for (const field of ['title', 'description', 'category', 'dailyAction']) {
    if (body[field] !== undefined) goal[field] = body[field];
  }
  if (body.targetDate !== undefined) goal.targetDate = body.targetDate;
  if (body.status !== undefined) applyStatus(goal, body.status, new Date());
  if (body.milestones !== undefined) {
    goal.milestones = mergeMilestones(goal.milestones, body.milestones);
  }
  goal.clientUpdatedAt = new Date();
  await goal.save();
  res.json({ data: toPublicGoal(goal, today) });
}

/**
 * Replaces a whole goal (used by sync). A write older than what the server
 * already holds is refused, so an out-of-date device cannot overwrite it.
 */
async function replaceGoal(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const body = parse(validators.replaceBody, req.body);
  const today = resolveToday(req.query);
  const goal = await Goal.findOne(owned(req, id));
  if (!goal) throw notFound();

  const stamp = new Date(body.clientUpdatedAt);
  if (stamp < goal.clientUpdatedAt) {
    throw new AppError(409, 'stale_write', 'The goal was changed more recently elsewhere');
  }

  goal.title = body.title;
  goal.description = body.description;
  goal.category = body.category;
  goal.targetDate = body.targetDate ?? null;
  goal.dailyAction = body.dailyAction;
  applyStatus(goal, body.status, stamp);
  goal.milestones = mergeMilestones(goal.milestones, body.milestones);
  goal.checkIns = [...new Set(body.checkIns)].sort();
  goal.clientUpdatedAt = stamp;
  await goal.save();
  res.json({ data: toPublicGoal(goal, today) });
}

async function deleteGoal(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const result = await Goal.deleteOne(owned(req, id));
  if (result.deletedCount === 0) throw notFound();
  res.status(204).end();
}

/** Marks the daily action done for a date. Safe to repeat. */
async function addCheckIn(req, res) {
  const { id } = parse(validators.idParam, req.params);
  const { date } = parse(validators.checkInBody, req.body);
  assertNearServerDate(date, 'date');
  const today = resolveToday(req.query);

  const goal = await Goal.findOneAndUpdate(
    { ...owned(req, id), status: 'active' },
    { $addToSet: { checkIns: date }, $set: { clientUpdatedAt: new Date() } },
    { new: true },
  );
  if (!goal) {
    if (await Goal.exists(owned(req, id))) {
      throw new AppError(409, 'goal_not_active', 'Only active goals can be checked in');
    }
    throw notFound();
  }
  res.json({ data: toPublicGoal(goal, today) });
}

/** Undoes a check-in. Safe to repeat. */
async function removeCheckIn(req, res) {
  const { id, date } = parse(validators.checkInParams, req.params);
  const today = resolveToday(req.query);
  const goal = await Goal.findOneAndUpdate(
    owned(req, id),
    { $pull: { checkIns: date }, $set: { clientUpdatedAt: new Date() } },
    { new: true },
  );
  if (!goal) throw notFound();
  res.json({ data: toPublicGoal(goal, today) });
}

module.exports = {
  listGoals,
  createGoal,
  getGoal,
  updateGoal,
  replaceGoal,
  deleteGoal,
  addCheckIn,
  removeCheckIn,
};
