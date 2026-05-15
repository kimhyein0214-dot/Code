import { Router } from 'express';

import { query } from '../db.js';

export const mappingRouter = Router();

mappingRouter.get('/summary', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT *
      FROM picking.v_order_items_master_match_summary
      ORDER BY master_match_status
    `);

    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

mappingRouter.get('/unmatched', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT
        raw_p_code,
        p_name,
        unmatched_reason,
        suggested_action,
        order_item_status,
        resolved,
        resolved_sku_id
      FROM stg.unmatched_order_items
      ORDER BY resolved ASC, raw_p_code
    `);

    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

mappingRouter.get('/own-sku/ambiguous', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 100), 500);
    const result = await query(
      `
      SELECT *
      FROM stg.v_ambiguous_own_sku_candidates
      ORDER BY candidate_count DESC, own_sku_code
      LIMIT $1
      `,
      [limit]
    );

    res.json({ data: result.rows, limit });
  } catch (err) {
    next(err);
  }
});

