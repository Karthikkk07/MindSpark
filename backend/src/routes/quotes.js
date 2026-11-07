'use strict';

const express = require('express');
const controller = require('../controllers/quotesController');

const router = express.Router();

// Fixed paths must come before the :id route.
router.get('/', controller.listQuotes);
router.get('/random', controller.randomQuote);
router.get('/categories', controller.listCategories);
router.get('/category/:category', controller.listByCategory);
router.get('/:id', controller.getQuote);

module.exports = router;
