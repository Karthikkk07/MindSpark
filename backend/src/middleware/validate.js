'use strict';

const AppError = require('../utils/AppError');

/** Validates data with a zod schema or throws a 400 AppError. */
function parse(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new AppError(
      400,
      'validation_error',
      'Invalid request',
      result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    );
  }
  return result.data;
}

module.exports = { parse };
