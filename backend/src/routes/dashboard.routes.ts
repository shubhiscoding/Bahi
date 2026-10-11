import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership } from '../middleware/businessAccess';
import { dashboardService } from '../services/dashboardService';
import { asyncHandler } from '../utils/asyncHandler';
import { parseDateRange } from '../utils/dateRange';

export const dashboardRoutes = Router({ mergeParams: true });

dashboardRoutes.use(requireAuth);

dashboardRoutes.get(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const filters = parseDateRange(req.query);
    if (!filters) return res.status(400).json({ error: 'INVALID_DATE_RANGE' });
    res.json(await dashboardService.getSummary(req.params.businessId, filters));
  }),
);

dashboardRoutes.get(
  '/rankings',
  requireMembership,
  asyncHandler(async (req, res) => {
    const filters = parseDateRange(req.query);
    if (!filters) return res.status(400).json({ error: 'INVALID_DATE_RANGE' });
    const kind = req.query.kind;
    if (kind !== 'buyers' && kind !== 'products') {
      return res.status(400).json({ error: 'INVALID_RANKING_KIND' });
    }
    res.json(await dashboardService.getRankings(req.params.businessId, filters, kind));
  }),
);
