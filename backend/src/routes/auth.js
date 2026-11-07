'use strict';

const express = require('express');
const createAuthController = require('../controllers/authController');

module.exports = function createAuthRouter(auth, authLimiter) {
  const controller = createAuthController(auth);
  const router = express.Router();
  router.post('/register', authLimiter, controller.register);
  router.post('/login', authLimiter, controller.login);
  router.get('/me', auth.requireAuth, controller.me);
  return router;
};
