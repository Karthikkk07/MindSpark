'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createApp } = require('../src/app');
const User = require('../src/models/User');

let mongod;
let app;
let counter = 0;

const secret = () => process.env.JWT_SECRET;
const post = (path, body) => request(app).post(path).send(body);

async function register(overrides = {}) {
  counter += 1;
  const body = {
    name: 'Ann',
    email: `ann${counter}@example.com`,
    password: 'password123',
    ...overrides,
  };
  const res = await post('/api/auth/register', body);
  return { res, body, token: res.body.token };
}

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  await User.init();
  app = createApp({ LOG_LEVEL: 'silent' });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});

describe('registration', () => {
  test('creates an account and returns a token without the password hash', async () => {
    const { res, body } = await register();
    expect(res.status).toBe(201);
    expect(res.body.token).toEqual(expect.any(String));
    expect(res.body.user).toMatchObject({ name: 'Ann', email: body.email });
    expect(JSON.stringify(res.body)).not.toMatch(/passwordHash|password123/);
  });

  test('stores a bcrypt hash, never the plain password', async () => {
    const { body } = await register();
    const stored = await User.findOne({ email: body.email }).select('+passwordHash');
    expect(stored.passwordHash).toMatch(/^\$2[aby]\$/);
    expect(stored.passwordHash).not.toContain('password123');
  });

  test('rejects a duplicate email, ignoring case', async () => {
    const { body } = await register();
    const res = await post('/api/auth/register', { ...body, email: body.email.toUpperCase() });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('email_taken');
  });

  test('validates input and rejects unexpected fields', async () => {
    const bad = [
      { name: 'A', email: 'not-an-email', password: 'password123' },
      { name: 'A', email: 'a@example.com', password: 'short' },
      { name: '', email: 'b@example.com', password: 'password123' },
      { email: 'c@example.com', password: 'password123' },
      { name: 'A', email: 'd@example.com', password: 'password123', role: 'admin' },
    ];
    for (const body of bad) {
      const res = await post('/api/auth/register', body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('validation_error');
    }
  });
});

describe('login', () => {
  test('logs in with the right password, email in any case', async () => {
    const { body } = await register();
    const res = await post('/api/auth/login', {
      email: body.email.toUpperCase(),
      password: body.password,
    });
    expect(res.status).toBe(200);
    expect(res.body.token).toEqual(expect.any(String));
  });

  test('wrong password and unknown email give the same 401', async () => {
    const { body } = await register();
    const wrong = await post('/api/auth/login', { email: body.email, password: 'wrong-password' });
    const unknown = await post('/api/auth/login', { email: 'nobody@example.com', password: 'whatever123' });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body).toEqual(unknown.body);
  });

  test('login attempts are rate limited', async () => {
    const limited = createApp({ LOG_LEVEL: 'silent', AUTH_RATE_LIMIT_MAX: 2 });
    const attempt = () =>
      request(limited).post('/api/auth/login').send({ email: 'x@example.com', password: 'password123' });
    await attempt();
    await attempt();
    const res = await attempt();
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('rate_limited');
  });
});

describe('GET /api/auth/me', () => {
  test('returns the account for a valid token', async () => {
    const { body, token } = await register();
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe(body.email);
  });

  test('rejects missing, malformed, wrongly signed and expired tokens', async () => {
    const { res } = await register();
    const id = res.body.user.id;
    const tokens = [
      undefined,
      'garbage',
      jwt.sign({}, 'another-secret-another-secret-123456', { subject: id }),
      jwt.sign({}, secret(), { subject: id, expiresIn: -10 }),
      jwt.sign({ sub: id }, '', { algorithm: 'none' }),
    ];
    for (const token of tokens) {
      const req = request(app).get('/api/auth/me');
      if (token !== undefined) req.set('Authorization', `Bearer ${token}`);
      const out = await req;
      expect(out.status).toBe(401);
    }
  });

  test('a token stops working once the account is deleted', async () => {
    const { token } = await register();
    await request(app).delete('/api/users/me').set('Authorization', `Bearer ${token}`).expect(204);
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(401);
  });
});
