'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const MODEL_PATH   = path.join(__dirname, '../../assets/model/banknote_classifier.tflite');
const LABELS_PATH  = path.join(__dirname, '../../assets/labels.txt');
const SCRIPT_PATH  = path.join(__dirname, 'inference.py');

// ── POST /api/classify ────────────────────────────────────────────────────────
// No auth required — accepts an image, returns classification results without
// saving to the database. Used by the Flutter web client.
exports.classify = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No image uploaded' });
  }

  const imagePath = req.file.path;

  try {
    const result = await _runPythonInference(imagePath);
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('[classify]', err.message);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    // Always clean up the temp upload file.
    fs.unlink(imagePath, () => {});
  }
};

// ── Private ───────────────────────────────────────────────────────────────────

function _runPythonInference(imagePath) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python', [SCRIPT_PATH, imagePath, MODEL_PATH, LABELS_PATH]);

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => (stdout += chunk));
    proc.stderr.on('data', (chunk) => (stderr += chunk));

    proc.on('close', (code) => {
      if (code !== 0) {
        return reject(new Error(stderr.trim() || `Python exited with code ${code}`));
      }
      try {
        resolve(JSON.parse(stdout.trim()));
      } catch {
        reject(new Error(`Invalid JSON from inference script: ${stdout}`));
      }
    });

    proc.on('error', (err) => reject(err));
  });
}
