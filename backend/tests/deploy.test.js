'use strict';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const Quote = require('../src/models/Quote');
const { seedQuotes, seedQuotesIfEmpty } = require('../src/services/quoteSeed');

let mongod;

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Quote.init();
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('quote seeding', () => {
  test('fills an empty database once and leaves existing quotes alone', async () => {
    const first = await seedQuotesIfEmpty();
    expect(first.inserted).toBeGreaterThan(0);
    expect(await Quote.countDocuments()).toBe(first.total);

    expect(await seedQuotesIfEmpty()).toBeNull();

    const again = await seedQuotes();
    expect(again.inserted).toBe(0);
    expect(await Quote.countDocuments()).toBe(first.total);
  });

  test('seeded quotes are served by the API in the app format', async () => {
    const app = createApp({ LOG_LEVEL: 'silent' });
    const res = await request(app).get('/api/quotes?limit=2');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data[0]).toEqual(
      expect.objectContaining({ id: expect.any(String), text: expect.any(String), category: expect.any(String) }),
    );
  });
});

describe('behind a proxy', () => {
  const get = (app, ip) => request(app).get('/api/health').set('X-Forwarded-For', ip);

  test('with TRUST_PROXY each client address has its own rate limit', async () => {
    const app = createApp({ LOG_LEVEL: 'silent', TRUST_PROXY: 1, RATE_LIMIT_MAX: 2 });
    expect((await get(app, '203.0.113.1')).status).toBe(200);
    expect((await get(app, '203.0.113.1')).status).toBe(200);
    expect((await get(app, '203.0.113.1')).status).toBe(429);
    expect((await get(app, '203.0.113.2')).status).toBe(200);
  });
});
