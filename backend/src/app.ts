import express from 'express';
import cors from 'cors';
import { env } from './env';
import { authRoutes } from './routes/auth.routes';
import { businessRoutes } from './routes/business.routes';
import { billRoutes } from './routes/bill.routes';
import { buyerRoutes } from './routes/buyer.routes';
import { depositRoutes } from './routes/deposit.routes';
import { devRoutes } from './routes/dev.routes';
import { inventoryRoutes } from './routes/inventory.routes';

/**
 * Builds the Express app with every route mounted, but never calls
 * .listen() — split out from index.ts so the test suite (Phase 8 §H) can
 * drive it directly with Supertest without a real listening port or
 * Socket.IO server. index.ts is the only place that wraps this in an HTTP
 * server + initializes sockets + actually listens.
 */
export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  // Temporary request logger — helps diagnose whether expected requests
  // (e.g. /auth/sync) are actually reaching the backend at all.
  app.use((req, _res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.originalUrl}`);
    next();
  });

  app.get('/health', (_req, res) => res.json({ ok: true }));

  app.use('/auth', authRoutes);
  app.use('/businesses', businessRoutes);
  app.use('/businesses/:businessId/items', inventoryRoutes);
  app.use('/businesses/:businessId/buyers', buyerRoutes);
  app.use('/businesses/:businessId/bills', billRoutes);
  app.use('/businesses/:businessId/deposits', depositRoutes);

  // Dev-only, never mounted in prod — see routes/dev.routes.ts.
  if (env.devMode) {
    console.log('DEV_MODE on — mounting /dev/* test routes');
    app.use('/dev', devRoutes);
  }

  // Basic error handler — surfaces unexpected errors as 500s instead of
  // crashing the process silently.
  app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
