import { Request, Response, NextFunction } from 'express';
import { prisma } from '../prisma';

/**
 * All the authorization logic that RLS was failing to express (recursion,
 * chicken-and-egg insert checks) now lives here — plain, debuggable
 * TypeScript instead of recursive SQL policies.
 */

// Attaches req.membership if the current user is a member of :businessId.
// Responds 403 and stops the chain if not.
export async function requireMembership(req: Request, res: Response, next: NextFunction) {
  const businessId = req.params.businessId;
  const userId = req.user!.id;

  const membership = await prisma.businessMember.findUnique({
    where: { businessId_userId: { businessId, userId } },
  });

  if (!membership) {
    return res.status(403).json({ error: 'Not a member of this business' });
  }

  req.membership = membership;
  next();
}

// Stricter variant: requires the member's role to be 'owner'.
// Assumes requireMembership already ran (or runs it first if not).
export async function requireOwner(req: Request, res: Response, next: NextFunction) {
  const businessId = req.params.businessId;
  const userId = req.user!.id;

  const membership =
    req.membership ??
    (await prisma.businessMember.findUnique({
      where: { businessId_userId: { businessId, userId } },
    }));

  if (!membership || membership.role !== 'owner') {
    return res.status(403).json({ error: 'Owner only' });
  }

  req.membership = membership;
  next();
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      membership?: { businessId: string; userId: string; role: string };
    }
  }
}
