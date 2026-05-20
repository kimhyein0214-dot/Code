import 'dotenv/config';
import cors from 'cors';
import express from 'express';

import { closePool } from './db.js';
import { healthRouter } from './routes/health.js';
import { mappingRouter } from './routes/mapping.js';
import { pickingRouter } from './routes/picking.js';
import { productCodeRouter } from './routes/product-code.js';
import { manualReviewRouter } from './modules/manual-review/routes.js';
import { productManagementRouter } from './modules/product-management/routes.js';

const app = express();
const port = Number(process.env.API_PORT || 8080);
const routeMounts = [
  '/health',
  '/api/manual-review',
  '/api/products',
  '/product-code',
  '/picking',
  '/mapping'
];

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.use('/health', healthRouter);
app.use('/api/manual-review', manualReviewRouter);
app.use('/api/products', productManagementRouter);
app.use('/product-code', productCodeRouter);
app.use('/picking', pickingRouter);
app.use('/mapping', mappingRouter);

app.use((req, res) => {
  res.status(404).json({
    error: 'not_found',
    path: req.path
  });
});

app.use((err, req, res, next) => {
  console.error(err);
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: err.code || 'internal_error',
    message: process.env.NODE_ENV === 'development' || statusCode < 500
      ? err.message
      : 'Internal server error'
  });
});

const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Product Ops API listening on :${port}`);
  console.log(`Mounted routes: ${routeMounts.join(', ')}`);
});

async function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
