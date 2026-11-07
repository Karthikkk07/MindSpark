'use strict';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const Quote = require('../src/models/Quote');
const User = require('../src/models/User');
const Favorite = require('../src/models/Favorite');

const base = { source: 's', license: 'l', author: 'Ann', tags: [] };
const QUOTES = [
  { ...base, quoteId: 'q1', text: 'One.', category: 'study', order: 0 },
  { ...base, quoteId: 'q2', text: 'Two.', category: 'coding', order: 1 },
  { ...base, quoteId: 'q3', text: 'Three.', category: 'coding', order: 2 },
  { ...base, quoteId: 'q4', text: 'Hidden.', category: 'study', order: 3, status: 'hidden' },
];

let mongod;
let app;
let counter = 0;

async function newUser() {
  counter += 1;
  const res = await request(app).post('/api/auth/register').send({
    name: 'Ann',
    email: `user${counter}@example.com`,
    password: 'password123',
  });
  return { token: res.body.token, id: res.body.user.id };
}

const as = (token) => ({
  get: (url) => request(app).get(url).set('Authorization', `Bearer ${token}`),
  post: (url, body) => request(app).post(url).set('Authorization', `Bearer ${token}`).send(body),
  patch: (url, body) => request(app).patch(url).set('Authorization', `Bearer ${token}`).send(body),
  del: (url) => request(app).delete(url).set('Authorization', `Bearer ${token}`),
});

const ids = (res) => res.body.data.map((quote) => quote.id);

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Promise.all([Quote.init(), User.init(), Favorite.init()]);
  await Quote.create(QUOTES);
  app = createApp({ LOG_LEVEL: 'silent' });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('preferences', () => {
  test('require authentication', async () => {
    expect((await request(app).get('/api/users/preferences')).status).toBe(401);
    expect((await request(app).patch('/api/users/preferences').send({})).status).toBe(401);
  });

  test('start with defaults and can be updated partially', async () => {
    const { token } = await newUser();
    const defaults = await as(token).get('/api/users/preferences');
    expect(defaults.body.data).toEqual({
      interests: [],
      themeMode: 'system',
      reminderEnabled: false,
      reminderHour: 8,
      reminderMinute: 0,
    });

    const updated = await as(token).patch('/api/users/preferences', {
      interests: ['coding', 'study', 'coding'],
      themeMode: 'dark',
    });
    expect(updated.status).toBe(200);
    expect(updated.body.data.interests).toEqual(['coding', 'study']);
    expect(updated.body.data.themeMode).toBe('dark');
    expect(updated.body.data.reminderHour).toBe(8);

    const again = await as(token).get('/api/users/preferences');
    expect(again.body.data.themeMode).toBe('dark');
  });

  test('reject invalid or empty updates', async () => {
    const { token } = await newUser();
    const bad = [
      {},
      { themeMode: 'sepia' },
      { interests: ['nope'] },
      { reminderHour: 24 },
      { reminderMinute: -1 },
      { reminderEnabled: 'yes' },
      { role: 'admin' },
    ];
    for (const body of bad) {
      const res = await as(token).patch('/api/users/preferences', body);
      expect(res.status).toBe(400);
    }
  });
});

describe('favorites', () => {
  test('require authentication', async () => {
    expect((await request(app).get('/api/favorites')).status).toBe(401);
    expect((await request(app).post('/api/favorites/q1')).status).toBe(401);
  });

  test('add is idempotent and never creates duplicates', async () => {
    const { token } = await newUser();
    const first = await as(token).post('/api/favorites/q1');
    const second = await as(token).post('/api/favorites/q1');
    expect(first.status).toBe(201);
    expect(second.status).toBe(200);
    expect(ids(await as(token).get('/api/favorites'))).toEqual(['q1']);
  });

  test('lists favorites newest first with public quote fields', async () => {
    const { token } = await newUser();
    await as(token).post('/api/favorites/q1');
    await as(token).post('/api/favorites/q2');
    await as(token).post('/api/favorites/q3');
    const res = await as(token).get('/api/favorites');
    expect(ids(res)).toEqual(['q3', 'q2', 'q1']);
    expect(res.body.data[0]).toMatchObject({ id: 'q3', text: 'Three.', category: 'coding' });
    expect(res.body.data[0]).not.toHaveProperty('_id');
  });

  test('unknown, hidden or malformed quote ids are rejected', async () => {
    const { token } = await newUser();
    expect((await as(token).post('/api/favorites/missing')).status).toBe(404);
    expect((await as(token).post('/api/favorites/q4')).status).toBe(404);
    expect((await as(token).post('/api/favorites/bad%20id')).status).toBe(400);
  });

  test('remove is idempotent', async () => {
    const { token } = await newUser();
    await as(token).post('/api/favorites/q1');
    expect((await as(token).del('/api/favorites/q1')).status).toBe(204);
    expect((await as(token).del('/api/favorites/q1')).status).toBe(204);
    expect(ids(await as(token).get('/api/favorites'))).toEqual([]);
  });

  test('users only see their own favorites', async () => {
    const ann = await newUser();
    const bob = await newUser();
    await as(ann.token).post('/api/favorites/q1');
    expect(ids(await as(bob.token).get('/api/favorites'))).toEqual([]);
  });

  test('merge adds known ids, ignores unknown ones and keeps the guest order', async () => {
    const { token } = await newUser();
    await as(token).post('/api/favorites/q2');
    const res = await as(token).post('/api/favorites/merge', {
      quoteIds: ['q1', 'missing', 'q3', 'q2', 'q1'],
    });
    expect(res.status).toBe(200);
    expect(ids(res)).toEqual(['q1', 'q3', 'q2']);
  });

  test('merge validates its input', async () => {
    const { token } = await newUser();
    for (const body of [{}, { quoteIds: 'q1' }, { quoteIds: ['bad id'] }, { quoteIds: ['q1'], extra: 1 }]) {
      expect((await as(token).post('/api/favorites/merge', body)).status).toBe(400);
    }
  });
});

describe('delete account', () => {
  test('removes the user and their favorites', async () => {
    const { token, id } = await newUser();
    await as(token).post('/api/favorites/q1');
    await as(token).del('/api/users/me').expect(204);
    expect(await User.countDocuments({ _id: id })).toBe(0);
    expect(await Favorite.countDocuments({ user: id })).toBe(0);
  });
});
