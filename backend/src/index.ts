import { createServer } from 'http';
import { createApp } from './app';
import { env } from './env';
import { initSockets } from './sockets';

const app = createApp();
const httpServer = createServer(app);
initSockets(httpServer);

httpServer.listen(env.port, () => {
  console.log(`Bahi backend listening on port ${env.port}`);
});

// Defense-in-depth: every known async path (routes, middleware, socket
// handlers) is now wrapped to prevent unhandled rejections. This is a
// last-resort net in case something is missed later — log and keep the
// process alive rather than taking the whole server down over one bad
// request, which is what happened before asyncHandler existed.
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled promise rejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
});
