'use strict';

const AppError = require('../utils/AppError');

function notFound(_req, _res, next) {
  next(new AppError(404, 'not_found', 'Route not found'));
}

// Express recognises error handlers by their four arguments.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  const known = err instanceof AppError;
  let status = 500;
  if (known) status = err.status;
  else if (Number.isInteger(err.status) && err.status >= 400 && err.status < 500) {
    status = err.status;
  }

  if (status >= 500 && req.log) req.log.error({ err }, 'Unhandled error');

  const body = { code: 'internal_error', message: 'Something went wrong' };
  if (known) {
    body.code = err.code;
    body.message = err.message;
    if (err.details) body.details = err.details;
  } else if (status < 500) {
    body.code = 'bad_request';
    body.message = 'Bad request';
  }
  res.status(status).json({ error: body });
}

module.exports = { notFound, errorHandler };
