import { Router } from 'express';

import {
  getSkuList,
  getSkusByCode
} from '../modules/product-management/service.js';

export const productCodeRouter = Router();

productCodeRouter.get('/skus', async (req, res, next) => {
  try {
    res.json(await getSkuList(req.query));
  } catch (err) {
    next(err);
  }
});

productCodeRouter.get('/skus/:selfpiaSkuCode', async (req, res, next) => {
  try {
    const result = await getSkusByCode('selfpia_sku', req.params.selfpiaSkuCode, { limit: 1 });
    if (result.data.length === 0) {
      res.status(404).json({ error: 'sku_not_found' });
      return;
    }

    res.json({ data: result.data[0] });
  } catch (err) {
    next(err);
  }
});
