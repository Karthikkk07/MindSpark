'use strict';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const User = require('../src/models/User');
const Goal = require('../src/models/Goal');
const { utcToday } = require('../src/services/streaks');

const shift = (base, days) =>
  new Date(Date.parse(`${base}T00:00:00Z`) + days * 86400000).toISOString().slice(0, 10);
const minutesAgo = (n) => new Date(Date.now() - n * 60000).toISOString();

let mongod;
let app;
let counter = 0;

async function newUser() {
  counter += 1;
  const res = await request(app).post('/api/auth/register').send({
    name: 'Ann',
    email: `syncuser${counter}@example.com`,
    password: 'password123',
  });
  return { token: res.body.token };
}

const as = (token) => ({
  get: (url) => request(app).get(url).set('Authorization', `Bearer ${token}`),
  post: (url, body) => request(app).post(url).set('Authorization', `Bearer ${token}`).send(body),
  put: (url, body) => request(app).put(url).set('Authorization', `Bearer ${token}`).send(body),
});

const body = (overrides = {}) => ({
  title: 'Read daily',
  category: 'growth',
  status: 'active',
  checkIns: [],
  clientUpdatedAt: minutesAgo(10),
  ...overrides,
});

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Promise.all([User.init(), Goal.init()]);
  app = createApp({ LOG_LEVEL: 'silent', RATE_LIMIT_MAX: 10000, AUTH_RATE_LIMIT_MAX: 1000 });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('creating with history', () => {
  test('keeps the status, check-in history and client change time', async () => {
    const { token } = await newUser();
    const today = utcToday();
    const stamp = minutesAgo(30);
    const res = await as(token).post('/api/goals', body({
      status: 'completed',
      checkIns: [shift(today, -5), shift(today, -4), shift(today, -4)],
      clientUpdatedAt: stamp,
    }));
    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('completed');
    expect(res.body.data.completedAt).toBe(stamp);
    expect(res.body.data.checkIns).toEqual([shift(today, -5), shift(today, -4)]);
    expect(res.body.data.clientUpdatedAt).toBe(stamp);
  });

  test('rejects history outside the allowed range and times in the future', async () => {
    const { token } = await newUser();
    const today = utcToday();
    const bad = [
      { checkIns: ['2019-12-31'] },
      { checkIns: [shift(today, 3)] },
      { clientUpdatedAt: new Date(Date.now() + 3 * 86400000).toISOString() },
      { clientUpdatedAt: 'not a time' },
    ];
    for (const overrides of bad) {
      expect((await as(token).post('/api/goals', body(overrides))).status).toBe(400);
    }
  });
});

describe('PUT /api/goals/:id', () => {
  async function create(token, overrides = {}) {
    const res = await as(token).post('/api/goals', body(overrides));
    return res.body.data;
  }

  test('replaces the whole goal, including check-ins', async () => {
    const { token } = await newUser();
    const today = utcToday();
    const goal = await create(token, { checkIns: [shift(today, -2), shift(today, -1)] });
    const stamp = minutesAgo(1);

    const res = await as(token).put(`/api/goals/${goal.id}`, body({
      title: 'Read more',
      description: 'Evenings',
      targetDate: '2027-02-01',
      dailyAction: '30 pages',
      status: 'completed',
      milestones: [{ title: 'One', done: true }],
      checkIns: [shift(today, -1)],
      clientUpdatedAt: stamp,
    }));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      title: 'Read more',
      description: 'Evenings',
      targetDate: '2027-02-01',
      dailyAction: '30 pages',
      status: 'completed',
      checkIns: [shift(today, -1)],
      clientUpdatedAt: stamp,
    });
    expect(res.body.data.completedAt).toBe(stamp);
    expect(res.body.data.progress).toEqual({ milestonesDone: 1, milestonesTotal: 1 });
  });

  test('keeps the ids of milestones that are sent back', async () => {
    const { token } = await newUser();
    const goal = await create(token, { milestones: [{ title: 'One' }, { title: 'Two' }] });
    const [one] = goal.milestones;

    const res = await as(token).put(`/api/goals/${goal.id}`, body({
      milestones: [{ id: one.id, title: 'One', done: true }],
      clientUpdatedAt: minutesAgo(1),
    }));

    expect(res.body.data.milestones).toHaveLength(1);
    expect(res.body.data.milestones[0].id).toBe(one.id);
  });

  test('refuses a write that is older than the stored one', async () => {
    const { token } = await newUser();
    const goal = await create(token, { clientUpdatedAt: minutesAgo(5) });

    const stale = await as(token).put(`/api/goals/${goal.id}`, body({
      title: 'Old edit',
      clientUpdatedAt: minutesAgo(20),
    }));
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('stale_write');

    const unchanged = await as(token).get(`/api/goals/${goal.id}`);
    expect(unchanged.body.data.title).toBe('Read daily');
  });

  test('another user cannot replace your goal, and bad bodies are refused', async () => {
    const ann = await newUser();
    const bob = await newUser();
    const goal = await create(ann.token);

    expect((await as(bob.token).put(`/api/goals/${goal.id}`, body())).status).toBe(404);

    const missingTime = body();
    delete missingTime.clientUpdatedAt;
    expect((await as(ann.token).put(`/api/goals/${goal.id}`, missingTime)).status).toBe(400);
    expect((await as(ann.token).put(`/api/goals/${goal.id}`, body({ extra: 1 }))).status).toBe(400);
  });

  test('a check-in made through the API counts as a newer change', async () => {
    const { token } = await newUser();
    const goal = await create(token, { clientUpdatedAt: minutesAgo(60) });

    const res = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: utcToday() });

    expect(Date.parse(res.body.data.clientUpdatedAt)).toBeGreaterThan(Date.parse(goal.clientUpdatedAt));
  });
});
