'use strict';

const { computeStreaks } = require('../services/streaks');

/** The API shape of a goal, with progress and streaks for [today]. */
function toPublicGoal(goal, today) {
  const checkIns = [...goal.checkIns].sort();
  const { current, longest } = computeStreaks(checkIns, today);
  const milestones = goal.milestones.map((milestone) => ({
    id: String(milestone._id),
    title: milestone.title,
    done: milestone.done,
  }));

  return {
    id: String(goal._id),
    title: goal.title,
    description: goal.description,
    category: goal.category,
    targetDate: goal.targetDate,
    status: goal.status,
    completedAt: goal.completedAt,
    dailyAction: goal.dailyAction,
    milestones,
    progress: {
      milestonesDone: milestones.filter((milestone) => milestone.done).length,
      milestonesTotal: milestones.length,
    },
    checkIns,
    streak: { current, longest, checkedInToday: checkIns.includes(today) },
    clientUpdatedAt: goal.clientUpdatedAt,
    createdAt: goal.createdAt,
    updatedAt: goal.updatedAt,
  };
}

module.exports = { toPublicGoal };
