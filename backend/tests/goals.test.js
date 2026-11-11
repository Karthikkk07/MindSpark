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

let mongod;
let app;
let counter = 0;

async function newUser() {
  counter += 1;
  const res = await request(app).post('/api/auth/register').send({
    name: 'Ann',
    email: `goaluser${counter}@example.com`,
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

async function createGoal(token, overrides = {}) {
  const res = await as(token).post('/api/goals', {
    title: 'Read daily',
    category: 'growth',
    ...overrides,
  });
  return res.body.data;
}

const titles = (res) => res.body.data.map((goal) => goal.title);

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Promise.all([User.init(), Goal.init()]);
  app = createApp({ LOG_LEVEL: 'silent' });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('authentication', () => {
  test('every goals endpoint requires a token', async () => {
    expect((await request(app).get('/api/goals')).status).toBe(401);
    expect((await request(app).post('/api/goals').send({})).status).toBe(401);
    expect((await request(app).get(`/api/goals/${'0'.repeat(24)}`)).status).toBe(401);
  });
});

describe('creating goals', () => {
  test('creates a goal with sensible defaults', async () => {
    const { token } = await newUser();
    const res = await as(token).post('/api/goals', { title: '  Read daily ', category: 'growth' });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      title: 'Read daily',
      status: 'active',
      description: '',
      dailyAction: '',
      targetDate: null,
      checkIns: [],
      streak: { current: 0, longest: 0, checkedInToday: false },
      progress: { milestonesDone: 0, milestonesTotal: 0 },
    });
  });

  test('keeps milestones, a daily action and a target date', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token, {
      targetDate: '2027-01-31',
      dailyAction: 'Read 20 minutes',
      milestones: [{ title: 'Chapter 1', done: true }, { title: 'Chapter 2' }],
    });
    expect(goal.targetDate).toBe('2027-01-31');
    expect(goal.dailyAction).toBe('Read 20 minutes');
    expect(goal.progress).toEqual({ milestonesDone: 1, milestonesTotal: 2 });
    expect(goal.milestones[0].id).toHaveLength(24);
  });

  test('rejects invalid input and unexpected fields', async () => {
    const { token } = await newUser();
    const bad = [
      {},
      { title: '', category: 'growth' },
      { title: 'x', category: 'nope' },
      { title: 'x', category: 'growth', targetDate: '2026-02-30' },
      { title: 'x', category: 'growth', role: 'admin' },
      { title: 'x', category: 'growth', milestones: Array(21).fill({ title: 'm' }) },
    ];
    for (const body of bad) {
      const res = await as(token).post('/api/goals', body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('validation_error');
    }
  });

  test('limits the number of goals per user', async () => {
    const { token, id } = await newUser();
    await Goal.insertMany(
      Array.from({ length: 100 }, (_, i) => ({ user: id, title: `Goal ${i}`, category: 'growth' })),
    );
    const res = await as(token).post('/api/goals', { title: 'One too many', category: 'growth' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('limit_reached');
  });
});

describe('listing and reading goals', () => {
  test('lists only your own goals, newest first', async () => {
    const ann = await newUser();
    const bob = await newUser();
    await createGoal(ann.token, { title: 'First' });
    await createGoal(ann.token, { title: 'Second' });
    await createGoal(bob.token, { title: 'Bob goal' });

    expect(titles(await as(ann.token).get('/api/goals'))).toEqual(['Second', 'First']);
    expect(titles(await as(bob.token).get('/api/goals'))).toEqual(['Bob goal']);
  });

  test('filters by status and rejects unknown statuses', async () => {
    const { token } = await newUser();
    const first = await createGoal(token, { title: 'First' });
    await createGoal(token, { title: 'Second' });
    await as(token).patch(`/api/goals/${first.id}`, { status: 'archived' });

    expect(titles(await as(token).get('/api/goals?status=archived'))).toEqual(['First']);
    expect(titles(await as(token).get('/api/goals?status=active'))).toEqual(['Second']);
    expect((await as(token).get('/api/goals?status=nope')).status).toBe(400);
  });

  test('reads one goal; other users, bad ids and unknown ids are refused', async () => {
    const ann = await newUser();
    const bob = await newUser();
    const goal = await createGoal(ann.token);

    expect((await as(ann.token).get(`/api/goals/${goal.id}`)).body.data.id).toBe(goal.id);
    expect((await as(bob.token).get(`/api/goals/${goal.id}`)).status).toBe(404);
    expect((await as(ann.token).get('/api/goals/not-an-id')).status).toBe(400);
    expect((await as(ann.token).get(`/api/goals/${'0'.repeat(24)}`)).status).toBe(404);
  });
});

describe('updating goals', () => {
  test('changes fields and clears the target date with null', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token, { targetDate: '2027-01-31' });
    const res = await as(token).patch(`/api/goals/${goal.id}`, {
      title: 'Read more',
      description: 'Every evening',
      category: 'study',
      dailyAction: '30 pages',
      targetDate: null,
    });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      title: 'Read more',
      description: 'Every evening',
      category: 'study',
      dailyAction: '30 pages',
      targetDate: null,
    });
  });

  test('completing a goal stamps the time, and reopening clears it', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);

    const done = await as(token).patch(`/api/goals/${goal.id}`, { status: 'completed' });
    expect(done.body.data.status).toBe('completed');
    expect(done.body.data.completedAt).not.toBeNull();

    const reopened = await as(token).patch(`/api/goals/${goal.id}`, { status: 'active' });
    expect(reopened.body.data.completedAt).toBeNull();
  });

  test('milestone updates keep ids, drop removed ones and add new ones', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token, {
      milestones: [{ title: 'One' }, { title: 'Two' }],
    });
    const [one] = goal.milestones;

    const res = await as(token).patch(`/api/goals/${goal.id}`, {
      milestones: [{ id: one.id, title: 'One (edited)', done: true }, { title: 'Three' }],
    });
    const { milestones, progress } = res.body.data;
    expect(milestones).toHaveLength(2);
    expect(milestones[0]).toMatchObject({ id: one.id, title: 'One (edited)', done: true });
    expect(milestones[1].title).toBe('Three');
    expect(progress).toEqual({ milestonesDone: 1, milestonesTotal: 2 });
  });

  test('rejects empty, invalid and unknown fields', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    for (const body of [{}, { status: 'done' }, { title: '' }, { owner: 'someone' }]) {
      expect((await as(token).patch(`/api/goals/${goal.id}`, body)).status).toBe(400);
    }
  });

  test('another user cannot change your goal', async () => {
    const ann = await newUser();
    const bob = await newUser();
    const goal = await createGoal(ann.token);
    expect((await as(bob.token).patch(`/api/goals/${goal.id}`, { title: 'Hacked' })).status).toBe(404);
    expect((await as(ann.token).get(`/api/goals/${goal.id}`)).body.data.title).toBe('Read daily');
  });
});

describe('check-ins and streaks', () => {
  const today = utcToday();

  test('a check-in today starts a streak', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    const res = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    expect(res.status).toBe(200);
    expect(res.body.data.checkIns).toEqual([today]);
    expect(res.body.data.streak).toEqual({ current: 1, longest: 1, checkedInToday: true });
  });

  test('repeating a check-in changes nothing', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    const again = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    expect(again.body.data.checkIns).toHaveLength(1);
  });

  test('consecutive days build the streak', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: shift(today, -1) });
    const res = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    expect(res.body.data.streak).toEqual({ current: 2, longest: 2, checkedInToday: true });
  });

  test('dates far from the server date or badly formatted are rejected', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    for (const date of [shift(today, -3), shift(today, 3), '2026-02-30', 'yesterday']) {
      const res = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date });
      expect(res.status).toBe(400);
    }
  });

  test('only active goals can be checked in', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    await as(token).patch(`/api/goals/${goal.id}`, { status: 'completed' });
    const res = await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('goal_not_active');
  });

  test('you cannot check in on someone else\'s goal', async () => {
    const ann = await newUser();
    const bob = await newUser();
    const goal = await createGoal(ann.token);
    const res = await as(bob.token).post(`/api/goals/${goal.id}/check-ins`, { date: today });
    expect(res.status).toBe(404);
  });

  test('undoing a check-in removes it and is safe to repeat', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: today });

    const first = await as(token).del(`/api/goals/${goal.id}/check-ins/${today}`);
    expect(first.status).toBe(200);
    expect(first.body.data.streak.current).toBe(0);
    const second = await as(token).del(`/api/goals/${goal.id}/check-ins/${today}`);
    expect(second.status).toBe(200);
  });

  test('the user\'s own date decides whether the streak is still alive', async () => {
    const { token } = await newUser();
    const goal = await createGoal(token);
    await as(token).post(`/api/goals/${goal.id}/check-ins`, { date: shift(today, -1) });

    const sameDay = await as(token).get(`/api/goals/${goal.id}`);
    expect(sameDay.body.data.streak.current).toBe(1);

    const nextDay = await as(token).get(`/api/goals/${goal.id}?today=${shift(today, 1)}`);
    expect(nextDay.body.data.streak).toEqual({ current: 0, longest: 1, checkedInToday: false });

    const tooFar = await as(token).get(`/api/goals/${goal.id}?today=${shift(today, 2)}`);
    expect(tooFar.status).toBe(400);
  });
});

describe('deleting', () => {
  test('deletes your goal, and others cannot delete it', async () => {
    const ann = await newUser();
    const bob = await newUser();
    const goal = await createGoal(ann.token);

    expect((await as(bob.token).del(`/api/goals/${goal.id}`)).status).toBe(404);
    expect((await as(ann.token).get(`/api/goals/${goal.id}`)).status).toBe(200);

    expect((await as(ann.token).del(`/api/goals/${goal.id}`)).status).toBe(204);
    expect((await as(ann.token).get(`/api/goals/${goal.id}`)).status).toBe(404);
  });

  test('deleting the account removes the goals too', async () => {
    const { token, id } = await newUser();
    await createGoal(token);
    await createGoal(token, { title: 'Another' });

    await as(token).del('/api/users/me').expect(204);

    expect(await Goal.countDocuments({ user: id })).toBe(0);
  });
});
