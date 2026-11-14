'use strict';

const express = require('express');
const { parse } = require('../middleware/validate');
const validators = require('../validators/aiValidators');

module.exports = function createAiRouter(auth, ai) {
  const router = express.Router();
  router.use(auth.requireAuth);

  router.post('/goal-suggestions', async (req, res) => {
    const body = parse(validators.suggestBody, req.body);
    res.json(await ai.suggestGoal(req.userId, body));
  });

  router.post('/encouragement', async (req, res) => {
    const body = parse(validators.encourageBody, req.body);
    res.json(await ai.encourage(req.userId, body));
  });

  return router;
};
