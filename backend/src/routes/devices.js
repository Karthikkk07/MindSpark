'use strict';

const express = require('express');
const controller = require('../controllers/devicesController');

module.exports = function createDevicesRouter(auth, push) {
  const router = express.Router();
  router.use(auth.requireAuth);
  router.post('/', controller.register);
  router.post('/unregister', controller.unregister);
  router.post('/test', controller.createSendTest(push));
  return router;
};
