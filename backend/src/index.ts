import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { env } from './env';
import { authRoutes } from './routes/auth.routes';
import { businessRoutes } from './routes/business.routes';
import { inventoryRoutes } from './routes/inventory.routes';
import { initSockets } from './sockets';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

app.use('/auth', authRoutes);
app.use('/businesses', businessRoutes);
app.use('/businesses/:businessId/items', inventoryRoutes);

// Basic error handler — surfaces unexpected errors as 500s instead of
// crashing the process silently.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const httpServer = createServer(app);
initSockets(httpServer);

httpServer.listen(env.port, () => {
  console.log(`Bahi backend listening on port ${env.port}`);
});
