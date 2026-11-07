'use strict';

const express = require('express');
const controller = require('../controllers/favoritesController');

module.exports = function createFavoritesRouter(auth) {
  const router = express.Router();
  router.use(auth.requireAuth);
  router.get('/', controller.list);
  router.post('/merge', controller.merge); // before /:quoteId
  router.post('/:quoteId', controller.add);
  router.delete('/:quoteId', controller.remove);
  return router;
};
