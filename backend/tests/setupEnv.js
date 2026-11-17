'use strict';

// Test-only settings, applied before any test file runs.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-test-secret-test-secret-123456';
process.env.BCRYPT_ROUNDS = '4';
process.env.AUTH_RATE_LIMIT_MAX = '1000';
// Tests never call the real AI service, even if backend/.env has a key.
process.env.GEMINI_API_KEY = '';
// Nor the real push service.
process.env.FIREBASE_SERVICE_ACCOUNT = '';
process.env.FIREBASE_SERVICE_ACCOUNT_PATH = '';
