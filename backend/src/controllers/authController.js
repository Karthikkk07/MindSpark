'use strict';

const User = require('../models/User');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const validators = require('../validators/userValidators');
const { toPublicUser } = require('../utils/serializers');

module.exports = function createAuthController(auth) {
  async function register(req, res) {
    const { name, email, password } = parse(validators.registerBody, req.body);
    const passwordHash = await auth.hashPassword(password);
    try {
      const user = await User.create({ name, email, passwordHash });
      res.status(201).json({ user: toPublicUser(user), token: auth.signToken(user._id) });
    } catch (err) {
      if (err && err.code === 11000) {
        throw new AppError(409, 'email_taken', 'An account with this email already exists');
      }
      throw err;
    }
  }

  async function login(req, res) {
    const { email, password } = parse(validators.loginBody, req.body);
    const user = await auth.verifyCredentials(email, password);
    res.json({ user: toPublicUser(user), token: auth.signToken(user._id) });
  }

  async function me(req, res) {
    const user = await User.findById(req.userId);
    if (!user) throw new AppError(401, 'unauthorized', 'Account no longer exists');
    res.json({ user: toPublicUser(user) });
  }

  return { register, login, me };
};
