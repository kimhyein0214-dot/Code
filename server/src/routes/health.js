import { Router } from 'express';

import { query } from '../db.js';

export const healthRouter = Router();

healthRouter.get('/', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT
        current_database() AS database,
        current_user AS user_name,
        now() AS checked_at
    `);

    res.json({
      ok: true,
      db: result.rows[0],
      service: 'product-ops-api-local'
    });
  } catch (err) {
    next(err);
  }
});

