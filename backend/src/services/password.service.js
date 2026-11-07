'use strict';

const bcrypt = require('bcryptjs');
const { loadEnv } = require('../config/env');

const config = loadEnv();

async function hashPassword(password) {
  return bcrypt.hash(password, config.BCRYPT_ROUNDS);
}

async function comparePassword(password, passwordHash) {
  return bcrypt.compare(password, passwordHash);
}

module.exports = {
  hashPassword,
  comparePassword,
};