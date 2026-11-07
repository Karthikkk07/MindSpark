'use strict';

const toPublicUser = (user) => ({
  id: String(user._id),
  name: user.name,
  email: user.email,
  createdAt: user.createdAt,
  preferences: {
    interests: [...user.preferences.interests],
    themeMode: user.preferences.themeMode,
    reminderEnabled: user.preferences.reminderEnabled,
    reminderHour: user.preferences.reminderHour,
    reminderMinute: user.preferences.reminderMinute,
  },
});

module.exports = { toPublicUser };
