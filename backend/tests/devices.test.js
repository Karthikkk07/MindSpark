'use strict';

const request = require('supertest');
const { generateKeyPairSync } = require('node:crypto');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const { createPushService } = require('../src/services/pushService');
const User = require('../src/models/User');
const DeviceToken = require('../src/models/DeviceToken');

const TOKEN_A = 'a'.repeat(40);
const TOKEN_B = 'b'.repeat(40);

let mongod;
let counter = 0;
let sendEach;

/** A stand-in for Firebase messaging that accepts every token. */
function fakeMessaging() {
  sendEach = jest.fn(async ({ tokens }) => ({
    successCount: tokens.length,
    failureCount: 0,
    responses: tokens.map(() => ({ success: true })),
  }));
  return { sendEachForMulticast: sendEach };
}

let app;

async function newUser() {
  counter += 1;
  const res = await request(app).post('/api/auth/register').send({
    name: 'Ann',
    email: `device${counter}@example.com`,
    password: 'password123',
  });
  return { token: res.body.token, id: res.body.user.id };
}

const as = (token) => ({
  post: (url, body) => request(app).post(url).set('Authorization', `Bearer ${token}`).send(body),
  del: (url) => request(app).delete(url).set('Authorization', `Bearer ${token}`),
});

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Promise.all([User.init(), DeviceToken.init()]);
  app = createApp({ LOG_LEVEL: 'silent', pushMessaging: fakeMessaging() });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

beforeEach(async () => {
  await DeviceToken.deleteMany({});
  sendEach.mockClear();
});

describe('device registration', () => {
  test('requires authentication', async () => {
    const res = await request(app).post('/api/devices').send({ token: TOKEN_A });
    expect(res.status).toBe(401);
  });

  test('rejects a missing or too short token', async () => {
    const { token } = await newUser();
    expect((await as(token).post('/api/devices', {})).status).toBe(400);
    expect((await as(token).post('/api/devices', { token: 'short' })).status).toBe(400);
  });

  test('saves a token once, however often it is sent', async () => {
    const { token, id } = await newUser();
    expect((await as(token).post('/api/devices', { token: TOKEN_A })).status).toBe(204);
    expect((await as(token).post('/api/devices', { token: TOKEN_A })).status).toBe(204);
    expect(await DeviceToken.countDocuments({ user: id })).toBe(1);
  });

  test('moves a token to the account that signs in on that phone', async () => {
    const first = await newUser();
    const second = await newUser();
    await as(first.token).post('/api/devices', { token: TOKEN_A });
    await as(second.token).post('/api/devices', { token: TOKEN_A });
    const saved = await DeviceToken.find({ token: TOKEN_A });
    expect(saved).toHaveLength(1);
    expect(String(saved[0].user)).toBe(second.id);
  });

  test('keeps only the newest 10 devices per user', async () => {
    const { token, id } = await newUser();
    for (let i = 0; i < 12; i += 1) {
      await as(token).post('/api/devices', { token: `${String(i).padStart(2, '0')}${'x'.repeat(30)}` });
    }
    expect(await DeviceToken.countDocuments({ user: id })).toBe(10);
    expect(await DeviceToken.exists({ token: `00${'x'.repeat(30)}` })).toBeNull();
  });

  test('unregister removes only the caller\'s token', async () => {
    const owner = await newUser();
    const other = await newUser();
    await as(owner.token).post('/api/devices', { token: TOKEN_A });

    await as(other.token).post('/api/devices/unregister', { token: TOKEN_A });
    expect(await DeviceToken.countDocuments({ token: TOKEN_A })).toBe(1);

    expect((await as(owner.token).post('/api/devices/unregister', { token: TOKEN_A })).status).toBe(204);
    expect(await DeviceToken.countDocuments({ token: TOKEN_A })).toBe(0);
  });

  test('deleting the account removes its tokens', async () => {
    const { token, id } = await newUser();
    await as(token).post('/api/devices', { token: TOKEN_A });
    expect((await as(token).del('/api/users/me')).status).toBe(204);
    expect(await DeviceToken.countDocuments({ user: id })).toBe(0);
  });
});

describe('test push', () => {
  test('sends to every device of the user', async () => {
    const { token } = await newUser();
    await as(token).post('/api/devices', { token: TOKEN_A });
    await as(token).post('/api/devices', { token: TOKEN_B });

    const res = await as(token).post('/api/devices/test', {});
    expect(res.status).toBe(200);
    expect(res.body.data.sent).toBe(2);
    expect(sendEach.mock.calls[0][0].tokens.sort()).toEqual([TOKEN_A, TOKEN_B]);
  });

  test('can wait before sending so the app can be closed', async () => {
    jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate', 'queueMicrotask'] });
    try {
      const { token } = await newUser();
      await as(token).post('/api/devices', { token: TOKEN_A });

      const res = await as(token).post('/api/devices/test', { delaySeconds: 10 });
      expect(res.body.data).toEqual({ sent: 1, delaySeconds: 10 });
      expect(sendEach).not.toHaveBeenCalled();

      await jest.advanceTimersByTimeAsync(10_000);
      // The send looks up the user's devices first, which is real database I/O.
      for (let i = 0; i < 200 && sendEach.mock.calls.length === 0; i += 1) {
        await new Promise((resolve) => setImmediate(resolve));
      }
      expect(sendEach).toHaveBeenCalledTimes(1);
    } finally {
      jest.useRealTimers();
    }
  });

  test('rejects a delay above 30 seconds', async () => {
    const { token } = await newUser();
    expect((await as(token).post('/api/devices/test', { delaySeconds: 31 })).status).toBe(400);
  });

  test('sends nothing when the user has no device', async () => {
    const { token } = await newUser();
    const res = await as(token).post('/api/devices/test', {});
    expect(res.body.data.sent).toBe(0);
    expect(sendEach).not.toHaveBeenCalled();
  });

  test('forgets tokens that Firebase reports as no longer valid', async () => {
    const { token } = await newUser();
    await as(token).post('/api/devices', { token: TOKEN_A });
    await as(token).post('/api/devices', { token: TOKEN_B });
    sendEach.mockImplementationOnce(async ({ tokens }) => ({
      successCount: 1,
      failureCount: 1,
      responses: tokens.map((t) =>
        t === TOKEN_A
          ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
          : { success: true },
      ),
    }));

    const res = await as(token).post('/api/devices/test', {});
    expect(res.body.data.sent).toBe(1);
    expect(await DeviceToken.countDocuments({ token: TOKEN_A })).toBe(0);
    expect(await DeviceToken.countDocuments({ token: TOKEN_B })).toBe(1);
  });

  test('a broken Firebase key switches push off instead of stopping the API', async () => {
    const broken = createApp({ LOG_LEVEL: 'silent', FIREBASE_SERVICE_ACCOUNT: '{"project_id":"x"}' });
    const reg = await request(broken).post('/api/auth/register').send({
      name: 'Cy',
      email: 'brokenkey@example.com',
      password: 'password123',
    });
    expect(reg.status).toBe(201);
    const res = await request(broken)
      .post('/api/devices/test')
      .set('Authorization', `Bearer ${reg.body.token}`)
      .send({});
    expect(res.status).toBe(503);
  });

  test('a well-formed Firebase key switches push on', () => {
    const { privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      publicKeyEncoding: { type: 'spki', format: 'pem' },
    });
    const key = JSON.stringify({
      type: 'service_account',
      project_id: 'demo-project',
      private_key: privateKey,
      client_email: 'push@demo-project.iam.gserviceaccount.com',
    });
    const push = createPushService({ FIREBASE_SERVICE_ACCOUNT: key }, { error: jest.fn() });
    expect(push.enabled).toBe(true);
  });

  test('answers 503 when push is not configured on the server', async () => {
    const unconfigured = createApp({ LOG_LEVEL: 'silent', pushMessaging: null });
    const reg = await request(unconfigured).post('/api/auth/register').send({
      name: 'Bo',
      email: 'nopush@example.com',
      password: 'password123',
    });
    const res = await request(unconfigured)
      .post('/api/devices/test')
      .set('Authorization', `Bearer ${reg.body.token}`)
      .send({});
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('push_unavailable');
  });
});
