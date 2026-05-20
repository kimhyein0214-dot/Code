import { Router } from 'express';

import {
  getCandidateDetail,
  getCandidateList,
  getSummary
} from './service.js';

export const manualReviewRouter = Router();

manualReviewRouter.get('/candidates', async (req, res, next) => {
  try {
    res.json(await getCandidateList(req.query));
  } catch (err) {
    next(err);
  }
});

manualReviewRouter.get('/summary', async (req, res, next) => {
  try {
    res.json(await getSummary());
  } catch (err) {
    next(err);
  }
});

manualReviewRouter.get('/candidates/:reviewCandidateId', async (req, res, next) => {
  try {
    res.json(await getCandidateDetail(req.params.reviewCandidateId));
  } catch (err) {
    next(err);
  }
});

manualReviewRouter.all('*', (req, res) => {
  res.set('Allow', 'GET');
  res.status(405).json({
    error: 'method_not_allowed',
    message: 'Manual review v1 API is read-only and only supports GET.'
  });
});
