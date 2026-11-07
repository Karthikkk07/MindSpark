'use strict';

const User = require('../models/User');
const Favorite = require('../models/Favorite');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const validators = require('../validators/userValidators');
const { toPublicUser } = require('../utils/serializers');

async function getPreferences(req, res) {
  const user = await User.findById(req.userId);
  if (!user) throw new AppError(401, 'unauthorized', 'Account no longer exists');
  res.json({ data: toPublicUser(user).preferences });
}

async function updatePreferences(req, res) {
  const body = parse(validators.preferencesBody, req.body);
  if (body.interests) body.interests = [...new Set(body.interests)];

  const updates = {};
  for (const [key, value] of Object.entries(body)) {
    updates[`preferences.${key}`] = value;
  }
  const user = await User.findByIdAndUpdate(
    req.userId,
    { $set: updates },
    { new: true, runValidators: true },
  );
  if (!user) throw new AppError(401, 'unauthorized', 'Account no longer exists');
  res.json({ data: toPublicUser(user).preferences });
}

/** Deletes the account and everything stored for it. */
async function deleteAccount(req, res) {
  await Favorite.deleteMany({ user: req.userId });
  await User.deleteOne({ _id: req.userId });
  res.status(204).end();
}

module.exports = { getPreferences, updatePreferences, deleteAccount };
