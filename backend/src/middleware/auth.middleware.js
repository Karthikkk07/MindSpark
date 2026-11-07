'use strict';

const AppError = require('../utils/AppError');
const User = require('../models/User');
const { verifyAccessToken } = require('../services/token.service');

async function authenticate(req, _res, next) {
  try {
    // Read the Authorization header.
    const authHeader = req.headers.authorization;

    // Check whether the token exists and uses Bearer format.
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError(401, 'unauthorized', 'Authentication token is required');
    }

    // Extract the token.
    const token = authHeader.split(' ')[1];

    if (!token) {
      throw new AppError(401, 'unauthorized', 'Authentication token is required');
    }

    // Verify the JWT.
    const decoded = verifyAccessToken(token);

    // Find the user associated with the token.
    const user = await User.findById(decoded.sub);

    if (!user) {
      throw new AppError(401, 'unauthorized', 'User no longer exists');
    }

    // Make the authenticated user available to route handlers.
    req.user = user;

    next();
  } catch (error) {
    if (error instanceof AppError) {
      return next(error);
    }

    if (
      error.name === 'JsonWebTokenError' ||
      error.name === 'TokenExpiredError' ||
      error.name === 'CastError'
    ) {
      return next(new AppError(401, 'unauthorized', 'Invalid or expired token'));
    }

    next(error);
  }
}

module.exports = { authenticate };
