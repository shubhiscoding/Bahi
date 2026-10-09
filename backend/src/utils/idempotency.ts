import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';

export const IDEMPOTENCY_KEY_HEADER = 'Idempotency-Key';

const KEY_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * Reads the Idempotency-Key header.
 * - undefined: header absent (older app builds) — write runs without replay protection.
 * - null: header present but malformed — route should reject with 400.
 * - string: a valid key.
 */
export function parseIdempotencyKey(raw: string | undefined): string | undefined | null {
  if (raw === undefined) return undefined;
  return KEY_PATTERN.test(raw) ? raw : null;
}

export interface IdempotentOutcome<T> {
  replayed: boolean;
  statusCode: number;
  body: T;
}

/**
 * Runs a write exactly once per (businessId, scope, key).
 *
 * The write and the stored response are committed in ONE transaction, so
 * a key row exists if and only if its write happened. A retry with the same
 * key gets the stored response back and writes nothing.
 *
 * Concurrency: if two identical requests race, both transactions try to
 * insert the same unique (businessId, scope, key). The loser blocks until
 * the winner commits, then fails with P2002, rolls back its own write, and
 * returns the winner's stored response.
 *
 * Only successful writes are stored. A validation error or thrown error
 * leaves no key row, so the client can fix the input and retry with the
 * same key.
 *
 * `work` must do all its writes through the `tx` it is given.
 */
export async function runIdempotent<T>(opts: {
  businessId: string;
  key: string | undefined;
  scope: string;
  statusCode: number;
  work: (tx: Prisma.TransactionClient) => Promise<T>;
}): Promise<IdempotentOutcome<T>> {
  const { businessId, key, scope, statusCode, work } = opts;

  if (key === undefined) {
    const body = await prisma.$transaction(work);
    return { replayed: false, statusCode, body };
  }

  const where = { businessId_scope_key: { businessId, scope, key } };

  const prior = await prisma.idempotencyKey.findUnique({ where });
  if (prior) {
    return { replayed: true, statusCode: prior.statusCode, body: prior.response as T };
  }

  try {
    const body = await prisma.$transaction(async (tx) => {
      const result = await work(tx);
      // Store the JSON form — the same thing res.json() would send — so a
      // replay is byte-for-byte what the first caller received.
      const json = JSON.parse(JSON.stringify(result)) as Prisma.InputJsonValue;
      await tx.idempotencyKey.create({
        data: { businessId, scope, key, statusCode, response: json },
      });
      return result;
    });
    return { replayed: false, statusCode, body };
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      const winner = await prisma.idempotencyKey.findUnique({ where });
      if (winner) {
        return { replayed: true, statusCode: winner.statusCode, body: winner.response as T };
      }
    }
    throw err;
  }
}
