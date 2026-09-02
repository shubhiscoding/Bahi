import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../prisma';
import { asyncHandler } from '../utils/asyncHandler';

/**
 * Dev-only routes — only mounted when env.devMode is true (see index.ts),
 * which only ever happens against .env.local (local Docker Postgres),
 * never in the real .env / EC2 deploy secrets.
 *
 * No auth bypass here: the caller still needs a real, valid Supabase JWT
 * (requireAuth runs as usual). This just lets an already-signed-in real
 * user flip their own membership role on the fixed seeded dev business
 * (see prisma/seed.ts's BUSINESS_ID) between 'owner' and 'member', so
 * both views can be tested from one real account without re-authenticating.
 */
export const devRoutes = Router();

devRoutes.use(requireAuth);

// Matches prisma/seed.ts's BUSINESS_ID constant.
const SEED_BUSINESS_ID = '33333333-3333-3333-3333-333333333333';

devRoutes.post(
  '/test-role',
  asyncHandler(async (req, res) => {
    const { role } = req.body;
    if (role !== 'owner' && role !== 'member') {
      return res.status(400).json({ error: "role must be 'owner' or 'member'" });
    }

    const business = await prisma.business.findUnique({ where: { id: SEED_BUSINESS_ID } });
    if (!business) {
      return res.status(404).json({ error: 'Seeded dev business not found — run npm run seed:local first' });
    }

    await prisma.businessMember.upsert({
      where: { businessId_userId: { businessId: SEED_BUSINESS_ID, userId: req.user!.id } },
      update: { role },
      create: { businessId: SEED_BUSINESS_ID, userId: req.user!.id, role },
    });

    res.json({ businessId: SEED_BUSINESS_ID, role });
  }),
);
