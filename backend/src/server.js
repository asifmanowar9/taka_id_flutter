'use strict';

require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`🚀  Server running on http://localhost:${PORT}`);
  console.log(`   Supabase URL: ${process.env.SUPABASE_URL || '(not set)'}`);
});
