'use strict';

const supabase = require('../lib/supabase');

/**
 * Express middleware that validates the Supabase JWT from the
 * Authorization: Bearer <token> header.
 *
 * On success, populates req.user with the Supabase User object.
 * On failure, returns 401 and short-circuits the request.
 */
module.exports = async (req, res, next) => {
  const auth = req.headers['authorization'];

  if (!auth?.startsWith('Bearer ')) {
    return res
      .status(401)
      .json({ success: false, error: 'Missing Authorization header' });
  }

  const token = auth.slice(7);

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (error || !user) {
    return res
      .status(401)
      .json({ success: false, error: 'Invalid or expired token' });
  }

  req.user = user;
  next();
};
