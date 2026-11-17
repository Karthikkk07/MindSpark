'use strict';

const DeviceToken = require('../models/DeviceToken');
const AppError = require('../utils/AppError');
const { parse } = require('../middleware/validate');
const validators = require('../validators/deviceValidators');

// Most people have a phone and a tablet; older tokens are dropped beyond this.
const MAX_DEVICES_PER_USER = 10;

/** Saves this install's push token for the signed-in user. Safe to repeat. */
async function register(req, res) {
  const { token } = parse(validators.tokenBody, req.body);
  // Upsert by token: signing in on a shared phone moves it to the new account.
  await DeviceToken.findOneAndUpdate(
    { token },
    { $set: { user: req.userId, platform: 'android' } },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );

  const stale = await DeviceToken.find({ user: req.userId })
    .sort({ updatedAt: -1 })
    .skip(MAX_DEVICES_PER_USER)
    .select('_id')
    .lean();
  if (stale.length > 0) {
    await DeviceToken.deleteMany({ _id: { $in: stale.map((device) => device._id) } });
  }
  res.status(204).end();
}

/** Stops push for one install (sign-out or push switched off). */
async function unregister(req, res) {
  const { token } = parse(validators.tokenBody, req.body);
  await DeviceToken.deleteOne({ token, user: req.userId });
  res.status(204).end();
}

function createSendTest(push) {
  const message = {
    title: 'MindSpark',
    body: 'Push notifications are working. Keep sparking!',
  };

  return async function sendTest(req, res) {
    if (!push.enabled) {
      throw new AppError(503, 'push_unavailable', 'Push notifications are not set up on the server');
    }
    const { delaySeconds = 0 } = parse(validators.testBody, req.body ?? {});
    if (delaySeconds === 0) {
      res.json({ data: { sent: await push.sendToUser(req.userId, message) } });
      return;
    }

    const devices = await DeviceToken.countDocuments({ user: req.userId });
    if (devices > 0) {
      setTimeout(() => {
        push.sendToUser(req.userId, message).catch((error) => {
          req.log.error({ err: error.message }, 'Delayed test push failed');
        });
      }, delaySeconds * 1000).unref();
    }
    res.json({ data: { sent: devices, delaySeconds } });
  };
}

module.exports = { register, unregister, createSendTest };
