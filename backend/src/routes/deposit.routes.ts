import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership } from '../middleware/businessAccess';
import { depositService } from '../services/depositService';
import { asyncHandler } from '../utils/asyncHandler';

// Mounted at /businesses/:businessId/deposits — see index.ts. Not
// nested under buyers (same as bill.routes.ts) since Deposit already
// carries businessId/buyerId directly.
export const depositRoutes = Router({ mergeParams: true });

depositRoutes.use(requireAuth);

depositRoutes.get(
  '/:depositId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const deposit = await depositService.getById(req.params.businessId, req.params.depositId);
    if (!deposit) return res.status(404).json({ error: 'DEPOSIT_NOT_FOUND' });
    res.json(deposit);
  }),
);
