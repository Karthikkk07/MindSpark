'use strict';

const jwt = require('jsonwebtoken');
const { loadEnv } = require('../config/env');

function createAccessToken(userId) {
  const config = loadEnv();

  if (!config.JWT_SECRET) {
    throw new Error('JWT_SECRET is missing from environment variables');
  }

  return jwt.sign(
    { sub: userId.toString() },
    config.JWT_SECRET,
    { expiresIn: config.JWT_EXPIRES_IN },
  );
}

function verifyAccessToken(token) {
  const config = loadEnv();

  if (!config.JWT_SECRET) {
    throw new Error('JWT_SECRET is missing from environment variables');
  }

  return jwt.verify(token, config.JWT_SECRET);
}

module.exports = {
  createAccessToken,
  verifyAccessToken,
};