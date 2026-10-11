import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership } from '../middleware/businessAccess';
import { depositService } from '../services/depositService';
import { asyncHandler } from '../utils/asyncHandler';
import { parseDateRange, parseSortOrder } from '../utils/dateRange';

// Mounted at /businesses/:businessId/deposits — see index.ts. Not
// nested under buyers (same as bill.routes.ts) since Deposit already
// carries businessId/buyerId directly.
export const depositRoutes = Router({ mergeParams: true });

depositRoutes.use(requireAuth);

depositRoutes.get(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const filters = parseDateRange(req.query);
    const sort = parseSortOrder(req.query.sort);
    if (!filters) return res.status(400).json({ error: 'INVALID_DATE_RANGE' });
    if (!sort) return res.status(400).json({ error: 'INVALID_SORT_ORDER' });
    res.json(await depositService.listForBusiness(req.params.businessId, filters, sort));
  }),
);

depositRoutes.get(
  '/:depositId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const deposit = await depositService.getById(req.params.businessId, req.params.depositId);
    if (!deposit) return res.status(404).json({ error: 'DEPOSIT_NOT_FOUND' });
    res.json(deposit);
  }),
);
