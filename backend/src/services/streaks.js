'use strict';

const DAY_MS = 24 * 60 * 60 * 1000;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/** True for a real calendar date written as YYYY-MM-DD. */
function isValidDateString(value) {
  if (typeof value !== 'string' || !DATE_PATTERN.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  if (year < 1000) return false;
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

/** Whole days since 1970-01-01 for a YYYY-MM-DD string (time zone free). */
function dayNumber(value) {
  const [year, month, day] = value.split('-').map(Number);
  return Math.round(Date.UTC(year, month - 1, day) / DAY_MS);
}

/** The server's current date in UTC as YYYY-MM-DD. */
function utcToday(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

/**
 * Streaks from a list of check-in dates (YYYY-MM-DD, any order).
 * [today] is the user's own calendar date, so time zones are respected.
 * The current streak stays alive until the end of the day after the last
 * check-in: a check-in yesterday still counts, one two days ago does not.
 */
function computeStreaks(checkIns, today) {
  const days = [...new Set(checkIns.filter(isValidDateString).map(dayNumber))].sort(
    (a, b) => a - b,
  );
  if (days.length === 0) return { current: 0, longest: 0 };

  let longest = 1;
  let run = 1;
  for (let i = 1; i < days.length; i += 1) {
    run = days[i] === days[i - 1] + 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  const todayNumber = dayNumber(today);
  const upToToday = days.filter((day) => day <= todayNumber);
  if (upToToday.length === 0) return { current: 0, longest };

  const last = upToToday[upToToday.length - 1];
  if (todayNumber - last > 1) return { current: 0, longest };

  let current = 1;
  for (let i = upToToday.length - 2; i >= 0 && upToToday[i] === upToToday[i + 1] - 1; i -= 1) {
    current += 1;
  }
  return { current, longest };
}

module.exports = { isValidDateString, dayNumber, utcToday, computeStreaks };
