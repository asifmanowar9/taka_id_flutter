'use strict';

const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload');
const {
  createRecord,
  getHistory,
  getRecord,
  deleteRecord,
} = require('../controllers/historyController');

// POST   /api/history          — save a new classification result + image
router.post('/', upload.single('image'), createRecord);

// GET    /api/history          — list all records (newest first)
router.get('/', getHistory);

// GET    /api/history/:id      — get one record by id
router.get('/:id', getRecord);

// DELETE /api/history/:id      — delete one record by id
router.delete('/:id', deleteRecord);

module.exports = router;
