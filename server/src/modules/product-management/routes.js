import { Router } from 'express';

import {
  getChangeRequestPlaceholder,
  getProductSearch,
  getSkuAliases,
  getSkuDetail,
  getSkuList,
  getSkusByCode
} from './service.js';

export const productManagementRouter = Router();

productManagementRouter.get('/skus', async (req, res, next) => {
  try {
    res.json(await getSkuList(req.query));
  } catch (err) {
    next(err);
  }
});

productManagementRouter.get('/skus/by-code/:codeSystem/:codeValue', async (req, res, next) => {
  try {
    res.json(await getSkusByCode(req.params.codeSystem, req.params.codeValue, req.query));
  } catch (err) {
    next(err);
  }
});

productManagementRouter.get('/skus/:skuId/aliases', async (req, res, next) => {
  try {
    res.json(await getSkuAliases(req.params.skuId));
  } catch (err) {
    next(err);
  }
});

productManagementRouter.get('/skus/:skuId', async (req, res, next) => {
  try {
    res.json(await getSkuDetail(req.params.skuId));
  } catch (err) {
    next(err);
  }
});

productManagementRouter.get('/search', async (req, res, next) => {
  try {
    res.json(await getProductSearch(req.query));
  } catch (err) {
    next(err);
  }
});

productManagementRouter.get('/change-requests', async (req, res, next) => {
  try {
    res.json(await getChangeRequestPlaceholder());
  } catch (err) {
    next(err);
  }
});
