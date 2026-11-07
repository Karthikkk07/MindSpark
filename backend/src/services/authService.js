'use strict';

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const AppError = require('../utils/AppError');

/** Password hashing, token signing and the authentication middleware. */
function createAuthService(env) {
  // Compared against when the email is unknown, so timing does not reveal it.
  const dummyHash = bcrypt.hashSync('not-a-real-password', env.BCRYPT_ROUNDS);

  const hashPassword = (password) => bcrypt.hash(password, env.BCRYPT_ROUNDS);

  const signToken = (userId) =>
    jwt.sign({}, env.JWT_SECRET, {
      algorithm: 'HS256',
      subject: String(userId),
      expiresIn: env.JWT_EXPIRES_IN,
    });

  async function verifyCredentials(email, password) {
    const user = await User.findOne({ email }).select('+passwordHash');
    const matches = await bcrypt.compare(password, user ? user.passwordHash : dummyHash);
    if (!user || !matches) {
      throw new AppError(401, 'invalid_credentials', 'Invalid email or password');
    }
    return user;
  }

  /** Sets req.userId from the verified token. Never trusts client-sent ids. */
  async function requireAuth(req, _res, next) {
    const [scheme, token] = (req.get('authorization') || '').split(' ');
    if (scheme !== 'Bearer' || !token) {
      return next(new AppError(401, 'unauthorized', 'Authentication required'));
    }
    let payload;
    try {
      payload = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
    } catch (_err) {
      return next(new AppError(401, 'unauthorized', 'Invalid or expired token'));
    }
    if (!mongoose.isValidObjectId(payload.sub) || !(await User.exists({ _id: payload.sub }))) {
      return next(new AppError(401, 'unauthorized', 'Invalid or expired token'));
    }
    req.userId = payload.sub;
    return next();
  }

  return { hashPassword, signToken, verifyCredentials, requireAuth };
}

module.exports = { createAuthService };
