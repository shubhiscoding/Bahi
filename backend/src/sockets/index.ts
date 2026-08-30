import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from '../env';
import { prisma } from '../prisma';

let io: SocketIOServer;

interface SupabaseJwtPayload {
  sub: string;
}

/** Initializes the Socket.IO server, wired to the same HTTP server as Express. */
export function initSockets(httpServer: HttpServer) {
  io = new SocketIOServer(httpServer, {
    cors: { origin: '*' }, // tighten once a deploy target/domain is chosen
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error('Missing auth token'));

    try {
      const payload = jwt.verify(token, env.supabaseJwtSecret) as SupabaseJwtPayload;
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('Invalid or expired token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    socket.on('join:business', async (businessId: string) => {
      const userId = socket.data.userId as string;

      // Re-check membership before letting the socket join the room —
      // same authorization rule as the REST middleware.
      const membership = await prisma.businessMember.findUnique({
        where: { businessId_userId: { businessId, userId } },
      });

      if (membership) {
        socket.join(roomFor(businessId));
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
