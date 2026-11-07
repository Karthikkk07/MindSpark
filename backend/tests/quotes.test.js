'use strict';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const Quote = require('../src/models/Quote');

const base = { source: 's', license: 'l' };
const FIXTURE = [
  { ...base, quoteId: 'q1', text: 'Zebra study note.', author: 'Ann', category: 'study', tags: ['Focus'], order: 1 },
  { ...base, quoteId: 'q2', text: 'Apple coding note.', author: 'Bob', category: 'coding', tags: ['debugging'], order: 2 },
  { ...base, quoteId: 'q3', text: 'Mango coding thought that is long.', author: 'Cy', category: 'coding', tags: ['craft'], order: 0 },
  { ...base, quoteId: 'q4', text: 'Hidden quote.', author: 'Dee', category: 'study', tags: [], order: 3, status: 'hidden' },
];

let mongod;
let app;

const ids = (res) => res.body.data.map((quote) => quote.id);

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await Quote.init();
  await Quote.create(FIXTURE);
  app = createApp({ LOG_LEVEL: 'silent', RATE_LIMIT_MAX: 1000 });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('health and basics', () => {
  test('health reports ok and the database state', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', db: 'up' });
  });

  test('unknown routes return a JSON 404', async () => {
    const res = await request(app).get('/api/nope');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('not_found');
  });

  test('security headers are set and x-powered-by is hidden', async () => {
    const res = await request(app).get('/api/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  test('rate limiting returns 429 when the limit is exceeded', async () => {
    const limited = createApp({ LOG_LEVEL: 'silent', RATE_LIMIT_MAX: 2 });
    await request(limited).get('/api/health');
    await request(limited).get('/api/health');
    const res = await request(limited).get('/api/health');
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('rate_limited');
  });
});

describe('GET /api/quotes', () => {
  test('lists published quotes in curated order with paging info', async () => {
    const res = await request(app).get('/api/quotes');
    expect(res.status).toBe(200);
    expect(ids(res)).toEqual(['q3', 'q1', 'q2']);
    expect(res.body).toMatchObject({ page: 1, limit: 20, total: 3, totalPages: 1 });
  });

  test('never returns hidden quotes or internal fields', async () => {
    const res = await request(app).get('/api/quotes');
    expect(ids(res)).not.toContain('q4');
    expect(res.body.data[0]).not.toHaveProperty('_id');
    expect(res.body.data[0]).not.toHaveProperty('status');
  });

  test('supports pagination', async () => {
    const res = await request(app).get('/api/quotes?limit=2&page=2');
    expect(ids(res)).toEqual(['q2']);
    expect(res.body.totalPages).toBe(2);
  });

  test('searches text, author and tags, ignoring case', async () => {
    expect(ids(await request(app).get('/api/quotes?search=APPLE'))).toEqual(['q2']);
    expect(ids(await request(app).get('/api/quotes?search=cy'))).toEqual(['q3']);
    expect(ids(await request(app).get('/api/quotes?search=focus'))).toEqual(['q1']);
  });

  test('treats special characters in search as plain text', async () => {
    const res = await request(app).get('/api/quotes?search=(');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('filters by category', async () => {
    const res = await request(app).get('/api/quotes?category=coding');
    expect(ids(res)).toEqual(['q3', 'q2']);
  });

  test('sorts A to Z and shortest first', async () => {
    expect(ids(await request(app).get('/api/quotes?sort=az'))).toEqual(['q2', 'q3', 'q1']);
    expect(ids(await request(app).get('/api/quotes?sort=shortest'))).toEqual(['q1', 'q2', 'q3']);
  });

  test('rejects invalid parameters with a 400', async () => {
    for (const query of ['category=nope', 'limit=100', 'page=0', 'sort=random']) {
      const res = await request(app).get(`/api/quotes?${query}`);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('validation_error');
    }
  });
});

describe('other quote endpoints', () => {
  test('random returns a published quote, optionally by category', async () => {
    const any = await request(app).get('/api/quotes/random');
    expect(['q1', 'q2', 'q3']).toContain(any.body.data.id);

    const study = await request(app).get('/api/quotes/random?category=study');
    expect(study.body.data.id).toBe('q1');
  });

  test('categories lists counts of published quotes', async () => {
    const res = await request(app).get('/api/quotes/categories');
    expect(res.body.data).toEqual([
      { id: 'coding', count: 2 },
      { id: 'study', count: 1 },
    ]);
  });

  test('category route lists quotes and validates the category', async () => {
    const ok = await request(app).get('/api/quotes/category/study');
    expect(ids(ok)).toEqual(['q1']);
    const bad = await request(app).get('/api/quotes/category/nope');
    expect(bad.status).toBe(400);
  });

  test('get by id returns a quote, 404 for hidden or unknown, 400 for bad ids', async () => {
    const found = await request(app).get('/api/quotes/q2');
    expect(found.status).toBe(200);
    expect(found.body.data).toMatchObject({ id: 'q2', author: 'Bob' });

    expect((await request(app).get('/api/quotes/q4')).status).toBe(404);
    expect((await request(app).get('/api/quotes/missing')).status).toBe(404);
    expect((await request(app).get('/api/quotes/bad%20id')).status).toBe(400);
  });
});
