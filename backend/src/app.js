'use strict';

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const historyRoutes = require('./routes/history');

const app = express();

// ── Middleware ─────────────────────────────────────────────────────────────
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());


// ── Routes ─────────────────────────────────────────────────────────────────
app.use('/api/history', historyRoutes);

// Health check — useful for uptime monitoring and smoke tests.
app.get('/health', (_, res) => res.json({ status: 'ok' }));

// 404 fallthrough
app.use((_, res) => res.status(404).json({ success: false, error: 'Not found' }));

// Global error handler
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ success: false, error: err.message });
});

module.exports = app;
