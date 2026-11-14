'use strict';

const AiUsage = require('../models/AiUsage');
const AppError = require('../utils/AppError');
const { utcToday } = require('./streaks');
const text = require('./aiText');

const limitReached = (limit) =>
  new AppError(429, 'ai_limit_reached', `You have used all ${limit} AI requests for today`);

/**
 * AI features with a per-user daily limit. [generate] is
 * async ({ system, user }) => string, or null when AI is switched off.
 */
function createAiService(env, generate, logger) {
  const limit = env.AI_DAILY_LIMIT;

  /** Takes one request from today's allowance. Atomic across requests. */
  async function reserve(userId, day) {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const usage = await AiUsage.findOneAndUpdate(
          { user: userId, day, count: { $lt: limit } },
          { $inc: { count: 1 } },
          { upsert: true, new: true },
        );
        return usage.count;
      } catch (err) {
        // The counter exists but is full, or two first requests raced.
        if (err.code !== 11000) throw err;
      }
    }
    throw limitReached(limit);
  }

  const refund = (userId, day) =>
    AiUsage.updateOne({ user: userId, day, count: { $gt: 0 } }, { $inc: { count: -1 } }).catch(
      () => {},
    );

  /** Runs one model call. A failed call is not charged to the user. */
  async function run(userId, system, payload, parse) {
    if (!generate) {
      throw new AppError(503, 'ai_unavailable', 'AI features are not available right now');
    }
    const day = utcToday();
    const used = await reserve(userId, day);
    try {
      const reply = await generate({ system, user: JSON.stringify(payload) });
      const data = parse(reply);
      return { data, remaining: Math.max(limit - used, 0) };
    } catch (err) {
      await refund(userId, day);
      // Only a status or code is logged, never prompts, replies or goal text.
      if (logger) logger.warn({ status: err && err.status, code: err && err.code }, 'AI request failed');
      throw text.upstreamError(err);
    }
  }

  const suggestGoal = (userId, goal) =>
    run(userId, text.GOAL_SYSTEM, { goal }, text.parseSuggestion);

  const encourage = (userId, progress) =>
    run(userId, text.COACH_SYSTEM, { progress }, text.parseEncouragement);

  return { suggestGoal, encourage };
}

module.exports = { createAiService };
