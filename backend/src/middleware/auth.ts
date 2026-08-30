import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../env';
import { prisma } from '../prisma';

export interface AuthenticatedUser {
  id: string;
  email?: string;
  fullName: string;
}

// Extend Express's Request type with our authenticated user
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

interface SupabaseJwtPayload {
  sub: string;
  email?: string;
  user_metadata?: {
    full_name?: string;
    name?: string;
  };
}

/**
 * Verifies the Supabase-issued JWT (Bearer token) on every request.
 * Replaces all RLS-based checks — this is the single source of truth for
 * "who is making this request" from here on.
 */
export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  const token = authHeader.slice('Bearer '.length);

  try {
    const payload = jwt.verify(token, env.supabaseJwtSecret) as SupabaseJwtPayload;

    req.user = {
      id: payload.sub,
      email: payload.email,
      fullName: payload.user_metadata?.full_name ?? payload.user_metadata?.name ?? payload.email ?? '?',
    };

    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/**
 * Upserts the current user's profile row from JWT claims.
 * Called by POST /auth/sync right after every sign-in — replaces the old
 * Postgres-trigger-based profile creation from the client's perspective.
 */
export async function upsertProfileFromAuth(user: AuthenticatedUser) {
  return prisma.profile.upsert({
    where: { id: user.id },
    update: { fullName: user.fullName },
    create: { id: user.id, fullName: user.fullName },
  });
}
