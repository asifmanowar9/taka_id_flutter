'use strict';

const mongoose = require('mongoose');

const topResultSchema = new mongoose.Schema(
  {
    label: { type: String, required: true },
    confidence: { type: Number, required: true, min: 0, max: 1 },
  },
  { _id: false },
);

const historyRecordSchema = new mongoose.Schema(
  {
    label: { type: String, required: true },
    confidence: { type: Number, required: true, min: 0, max: 1 },
    topResults: { type: [topResultSchema], default: [] },

    // URL path served by Express (e.g. http://localhost:3000/uploads/img.jpg)
    imageUrl: { type: String },

    // Original absolute path on the device — stored for reference only.
    localImagePath: { type: String, default: '' },

    // When the classification happened on the device.
    timestamp: { type: Date, required: true, default: Date.now },
  },
  {
    // Adds createdAt / updatedAt automatically.
    timestamps: true,
  },
);

module.exports = mongoose.model('HistoryRecord', historyRecordSchema);
