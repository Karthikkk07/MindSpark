'use strict';

const mongoose = require('mongoose');

async function connectDb(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 10000 });
}

module.exports = { connectDb };
