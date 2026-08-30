import { PrismaClient } from '@prisma/client';

// Singleton Prisma client — direct Postgres connection, bypasses
// PostgREST/RLS entirely. Authorization is enforced in middleware instead.
export const prisma = new PrismaClient();
