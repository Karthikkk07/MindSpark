'use strict';

const { isValidDateString, dayNumber, utcToday, computeStreaks } = require('../src/services/streaks');

const shift = (base, days) =>
  new Date(Date.parse(`${base}T00:00:00Z`) + days * 86400000).toISOString().slice(0, 10);
const T = '2026-11-10';
const dates = (...offsets) => offsets.map((n) => shift(T, n));

describe('date helpers', () => {
  test('accepts real calendar dates only', () => {
    expect(isValidDateString('2028-02-29')).toBe(true);
    for (const bad of ['2027-02-29', '2027-13-01', '2027-1-1', 'abc', '', null, '0050-01-01', '2027-04-31']) {
      expect(isValidDateString(bad)).toBe(false);
    }
  });

  test('utcToday uses the UTC date', () => {
    expect(utcToday(new Date('2026-11-09T23:59:59Z'))).toBe('2026-11-09');
  });

  test('dayNumber counts whole days', () => {
    expect(dayNumber('1970-01-02') - dayNumber('1970-01-01')).toBe(1);
  });
});

describe('computeStreaks', () => {
  test('no check-ins', () => {
    expect(computeStreaks([], T)).toEqual({ current: 0, longest: 0 });
  });

  test('a check-in today or yesterday keeps the streak alive', () => {
    expect(computeStreaks([T], T)).toEqual({ current: 1, longest: 1 });
    expect(computeStreaks(dates(-1), T)).toEqual({ current: 1, longest: 1 });
  });

  test('two days without a check-in resets the current streak', () => {
    expect(computeStreaks(dates(-2), T)).toEqual({ current: 0, longest: 1 });
  });

  test('counts a run of consecutive days', () => {
    expect(computeStreaks(dates(-4, -3, -2, -1, 0), T)).toEqual({ current: 5, longest: 5 });
  });

  test('separates the current streak from the longest one', () => {
    expect(computeStreaks(dates(-9, -8, -7, -2, -1), T)).toEqual({ current: 2, longest: 3 });
    expect(computeStreaks(dates(-9, -8, -7, -5, -4), T)).toEqual({ current: 0, longest: 3 });
  });

  test('ignores duplicates, order and invalid entries', () => {
    expect(computeStreaks([T, shift(T, -1), T, 'junk', shift(T, -1)], T)).toEqual({
      current: 2,
      longest: 2,
    });
  });

  test('future days do not count towards the current streak', () => {
    expect(computeStreaks([shift(T, 1), T], T)).toEqual({ current: 1, longest: 2 });
  });

  test('works across month, year and leap-day boundaries', () => {
    expect(computeStreaks(['2027-01-01', '2026-12-31', '2026-12-30'], '2027-01-01')).toEqual({ current: 3, longest: 3 });
    expect(computeStreaks(['2028-03-01', '2028-02-29', '2028-02-28'], '2028-03-01')).toEqual({ current: 3, longest: 3 });
    expect(computeStreaks(['2027-03-01', '2027-02-28'], '2027-03-01')).toEqual({ current: 2, longest: 2 });
  });
});
