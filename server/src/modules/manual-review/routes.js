import { Router } from 'express';

import {
  getDecision,
  getCandidateDetail,
  getCandidateList,
  getSummary,
  saveDecision
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

manualReviewRouter.get('/decisions/:reviewCandidateId', async (req, res, next) => {
  try {
    res.json(await getDecision(req.params.reviewCandidateId));
  } catch (err) {
    next(err);
  }
});

manualReviewRouter.post('/decisions', async (req, res, next) => {
  try {
    res.status(201).json(await saveDecision(req.body));
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
  res.set('Allow', 'GET, POST');
  res.status(405).json({
    error: 'method_not_allowed',
    message: 'Manual review API supports GET plus POST /decisions for local decision storage.'
  });
});
