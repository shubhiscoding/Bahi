import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { verifySupabaseJwt } from '../jwtVerify';
import { prisma } from '../prisma';

let io: SocketIOServer;

/** Initializes the Socket.IO server, wired to the same HTTP server as Express. */
export function initSockets(httpServer: HttpServer) {
  io = new SocketIOServer(httpServer, {
    cors: { origin: '*' }, // tighten once a deploy target/domain is chosen
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error('Missing auth token'));

    verifySupabaseJwt(token)
      .then((payload) => {
        socket.data.userId = payload.sub;
        next();
      })
      .catch(() => next(new Error('Invalid or expired token')));
  });

  io.on('connection', (socket: Socket) => {
    // Wrapped in try/catch: a thrown/rejected error inside a bare async
    // socket event handler is an unhandled rejection that crashes the
    // whole process (same class of bug fixed via asyncHandler for REST).
    socket.on('join:business', async (businessId: string) => {
      try {
        const userId = socket.data.userId as string;

        // Re-check membership before letting the socket join the room —
        // same authorization rule as the REST middleware.
        const membership = await prisma.businessMember.findUnique({
          where: { businessId_userId: { businessId, userId } },
        });

        if (membership) {
          socket.join(roomFor(businessId));
        }
      } catch (err) {
        console.error('join:business error', err);
      }
    });

    socket.on('leave:business', (businessId: string) => {
      socket.leave(roomFor(businessId));
    });
  });

  return io;
}

function roomFor(businessId: string) {
  return `business:${businessId}`;
}

/** Emit an event to everyone currently viewing this business (called from REST route handlers after a successful write). */
export function emitToBusiness(businessId: string, event: string, payload: unknown) {
  io.to(roomFor(businessId)).emit(event, payload);
}
