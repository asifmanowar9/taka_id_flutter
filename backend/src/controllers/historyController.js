'use strict';

const fs = require('fs');
const path = require('path');
const supabase = require('../lib/supabase');

const TABLE = 'history_records';
const BUCKET = process.env.SUPABASE_STORAGE_BUCKET || 'banknotes';

// ── POST /api/history ─────────────────────────────────────────────────────────
exports.createRecord = async (req, res) => {
  try {
    const { label, confidence, topResults, timestamp, localImagePath } =
      req.body;

    let parsedTopResults = [];
    try {
      parsedTopResults = JSON.parse(topResults || '[]');
    } catch {
      parsedTopResults = [];
    }

    const imageUrl = await _uploadImage(req.file);

    const { data, error } = await supabase
      .from(TABLE)
      .insert({
        user_id: req.user.id,
        label,
        confidence: parseFloat(confidence),
        top_results: parsedTopResults,
        image_url: imageUrl,
        local_image_path: localImagePath || '',
        timestamp: timestamp ? new Date(timestamp).toISOString() : new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({ success: true, data: _toResponse(data) });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// ── GET /api/history ──────────────────────────────────────────────────────────
exports.getHistory = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from(TABLE)
      .select('*')
      .eq('user_id', req.user.id)
      .order('timestamp', { ascending: false });

    if (error) throw error;

    res.json({ success: true, data: data.map(_toResponse) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// ── GET /api/history/:id ──────────────────────────────────────────────────────
exports.getRecord = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from(TABLE)
      .select('*')
      .eq('id', req.params.id)
      .eq('user_id', req.user.id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return res.status(404).json({ success: false, error: 'Record not found' });
      }
      throw error;
    }

    res.json({ success: true, data: _toResponse(data) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// ── DELETE /api/history/:id ───────────────────────────────────────────────────
exports.deleteRecord = async (req, res) => {
  try {
    // Fetch image_url first so we can clean up Storage.
    const { data: existing, error: fetchError } = await supabase
      .from(TABLE)
      .select('image_url')
      .eq('id', req.params.id)
      .eq('user_id', req.user.id)
      .single();

    if (fetchError) {
      if (fetchError.code === 'PGRST116') {
        return res.status(404).json({ success: false, error: 'Record not found' });
      }
      throw fetchError;
    }

    const { error } = await supabase
      .from(TABLE)
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', req.user.id);

    if (error) throw error;

    // Remove image from Storage (non-fatal if it fails).
    if (existing?.image_url) {
      const storageKey = _extractStorageKey(existing.image_url);
      if (storageKey) {
        await supabase.storage.from(BUCKET).remove([storageKey]).catch(() => {});
      }
    }

    res.json({ success: true, message: 'Record deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// ── Private helpers ───────────────────────────────────────────────────────────

/** Upload a multer file to Supabase Storage; returns the public URL or null. */
async function _uploadImage(file) {
  if (!file) return null;

  const ext = path.extname(file.originalname) || '.jpg';
  const storageKey = `banknote_${Date.now()}${ext}`;

  const fileBuffer = fs.readFileSync(file.path);

  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(storageKey, fileBuffer, { contentType: file.mimetype, upsert: false });

  // Always delete the local temp file Multer created.
  fs.unlink(file.path, () => {});

  if (error) throw error;

  const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(storageKey);
  return urlData.publicUrl;
}

/** Map snake_case DB row → camelCase shape the Flutter model expects. */
function _toResponse(row) {
  return {
    _id: row.id,
    label: row.label,
    confidence: row.confidence,
    topResults: row.top_results,
    imageUrl: row.image_url,
    localImagePath: row.local_image_path,
    timestamp: row.timestamp,
  };
}

/** Extract the storage object key from a Supabase public URL. */
function _extractStorageKey(publicUrl) {
  try {
    const url = new URL(publicUrl);
    // URL format: /storage/v1/object/public/<bucket>/<key>
    const parts = url.pathname.split(`/object/public/${BUCKET}/`);
    return parts.length > 1 ? parts[1] : null;
  } catch {
    return null;
  }
}
