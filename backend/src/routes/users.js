'use strict';

const express = require('express');
const controller = require('../controllers/usersController');

module.exports = function createUsersRouter(auth) {
  const router = express.Router();
  router.use(auth.requireAuth);
  router.get('/preferences', controller.getPreferences);
  router.patch('/preferences', controller.updatePreferences);
  router.delete('/me', controller.deleteAccount);
  return router;
};
