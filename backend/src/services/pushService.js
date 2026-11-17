'use strict';

const fs = require('node:fs');

const DeviceToken = require('../models/DeviceToken');

// Render mounts secret files here; used when no path is configured.
const DEFAULT_SECRET_PATH = '/etc/secrets/firebase-service-account.json';

// Codes that mean the token will never work again.
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function readServiceAccount(env) {
  if (env.FIREBASE_SERVICE_ACCOUNT) return JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const path =
    env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    (fs.existsSync(DEFAULT_SECRET_PATH) ? DEFAULT_SECRET_PATH : null);
  return path ? JSON.parse(fs.readFileSync(path, 'utf8')) : null;
}

/** Connects to Firebase Cloud Messaging, or returns null when it is not configured. */
function createFirebaseMessaging(env, logger) {
  let serviceAccount;
  try {
    serviceAccount = readServiceAccount(env);
  } catch (error) {
    logger.error({ err: error.message }, 'Firebase service account could not be read');
    return null;
  }
  if (!serviceAccount) return null;
  // Loaded only when configured, so local runs and tests stay light.
  const admin = require('firebase-admin');
  const app = admin.initializeApp(
    { credential: admin.credential.cert(serviceAccount) },
    `mindspark-${Date.now()}`,
  );
  return admin.messaging(app);
}

/**
 * Sends push notifications to a user's registered devices.
 * `messaging` can be replaced in tests; null switches push off.
 */
function createPushService(env, logger, messaging = createFirebaseMessaging(env, logger)) {
  return {
    enabled: Boolean(messaging),

    /** Returns how many devices accepted the message. */
    async sendToUser(userId, { title, body }) {
      if (!messaging) return 0;
      const devices = await DeviceToken.find({ user: userId }).select('token').lean();
      if (devices.length === 0) return 0;

      const tokens = devices.map((device) => device.token);
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: { title, body },
        android: { priority: 'high' },
      });

      const dead = [];
      response.responses.forEach((result, index) => {
        if (!result.success && DEAD_TOKEN_CODES.has(result.error?.code)) {
          dead.push(tokens[index]);
        }
      });
      if (dead.length > 0) await DeviceToken.deleteMany({ token: { $in: dead } });
      return response.successCount;
    },
  };
}

module.exports = { createPushService };
