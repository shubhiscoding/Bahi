import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { prisma } from '../src/prisma';
import { inventoryService } from '../src/services/inventoryService';

export const app = createApp();

/**
 * Builds a bearer token requireAuth's test-only bypass understands (see
 * src/middleware/auth.ts) — NODE_ENV=test only, never valid otherwise.
 * fullName must not contain ':' (the bypass splits on it).
 */
export function authHeader(userId: string, fullName = 'Test User') {
  return `Bearer test:${userId}:${fullName}`;
}

/**
 * Creates a fresh profile + business + owner membership for one test
 * file — every test file uses its own randomly-generated IDs, so
 * multiple test files can share the same bahi_test database (reset once
 * per `npm test` run, not per file) without colliding.
 */
export async function makeTestBusiness() {
  const ownerId = randomUUID();
  const businessId = randomUUID();

  await prisma.profile.create({ data: { id: ownerId, fullName: 'Test Owner' } });
  await prisma.business.create({
    data: {
      id: businessId,
      name: 'Test Business',
      ownerId,
      members: { create: { userId: ownerId, role: 'owner' } },
    },
  });

  return { ownerId, businessId };
}

export async function makeTestMember(businessId: string, role: 'owner' | 'member' = 'member') {
  const userId = randomUUID();
  await prisma.profile.create({ data: { id: userId, fullName: 'Test Member' } });
  await prisma.businessMember.create({ data: { businessId, userId, role } });
  return userId;
}

/**
 * Goes through the real inventoryService.create() (not a raw
 * prisma.inventoryItem.create()) — that's what actually seeds the
 * initial price-history row every real item gets. Bypassing the service
 * here would make fixtures diverge from real behavior, exactly the kind
 * of gap this test suite exists to catch.
 */
export async function makeTestItem(
  businessId: string,
  ownerId: string,
  overrides: Partial<{ name: string; price: number; quantity: number; unit: string }> = {},
) {
  return inventoryService.create(businessId, ownerId, {
    name: overrides.name ?? 'Test Item',
    price: overrides.price ?? 10,
    quantity: overrides.quantity ?? 100,
    unit: overrides.unit ?? 'piece',
  });
}
