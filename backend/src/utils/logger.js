'use strict';

const pino = require('pino');

function createLogger(level = 'info') {
  return pino({
    level,
    redact: ['req.headers.authorization', 'req.headers.cookie'],
  });
}

module.exports = { createLogger };
