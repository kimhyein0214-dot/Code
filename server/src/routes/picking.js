import { Router } from 'express';

import { query } from '../db.js';

export const pickingRouter = Router();

pickingRouter.get('/orders', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 50), 200);
    const result = await query(
      `
      SELECT
        order_id,
        raw_ord_no,
        inv_no,
        channel_code,
        order_date,
        order_status,
        cs_status,
        created_at
      FROM picking.orders
      ORDER BY created_at DESC, order_id
      LIMIT $1
      `,
      [limit]
    );

    res.json({ data: result.rows, limit });
  } catch (err) {
    next(err);
  }
});

pickingRouter.get('/order-items', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 50), 200);
    const status = req.query.master_match_status || null;

    const result = await query(
      `
      SELECT
        order_item_id,
        raw_item_no,
        order_id,
        raw_ord_no,
        inv_no,
        raw_p_code,
        p_name,
        p_option,
        qty_ordered,
        order_item_status,
        sku_id,
        selfpia_sku_code,
        master_match_status,
        master_match_note
      FROM picking.order_items
      WHERE $1::text IS NULL OR master_match_status = $1
      ORDER BY order_item_id DESC
      LIMIT $2
      `,
      [status, limit]
    );

    res.json({ data: result.rows, limit });
  } catch (err) {
    next(err);
  }
});

pickingRouter.get('/unmatched', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 100), 500);
    const result = await query(
      `
      SELECT *
      FROM picking.v_order_items_unmatched
      ORDER BY order_item_id DESC
      LIMIT $1
      `,
      [limit]
    );

    res.json({ data: result.rows, limit });
  } catch (err) {
    next(err);
  }
});

