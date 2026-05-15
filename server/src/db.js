import pg from 'pg';

const { Pool } = pg;

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL is required');
}

const sslMode = process.env.PGSSLMODE || 'disable';

export const pool = new Pool({
  connectionString,
  ssl: sslMode === 'require' ? { rejectUnauthorized: false } : false,
  max: Number(process.env.PGPOOL_MAX || 10),
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000
});

export async function query(text, params = []) {
  if (process.env.LOG_SQL === 'true') {
    console.log('[sql]', text, params);
  }
  return pool.query(text, params);
}

export async function closePool() {
  await pool.end();
}

