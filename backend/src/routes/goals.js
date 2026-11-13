'use strict';

const express = require('express');
const controller = require('../controllers/goalsController');

module.exports = function createGoalsRouter(auth) {
  const router = express.Router();
  router.use(auth.requireAuth);
  router.get('/', controller.listGoals);
  router.post('/', controller.createGoal);
  router.get('/:id', controller.getGoal);
  router.patch('/:id', controller.updateGoal);
  router.put('/:id', controller.replaceGoal);
  router.delete('/:id', controller.deleteGoal);
  router.post('/:id/check-ins', controller.addCheckIn);
  router.delete('/:id/check-ins/:date', controller.removeCheckIn);
  return router;
};
