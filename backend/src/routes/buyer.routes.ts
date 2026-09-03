import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership } from '../middleware/businessAccess';
import { buyerService } from '../services/buyerService';
import { billService } from '../services/billService';
import { emitToBusiness } from '../sockets';
import { asyncHandler } from '../utils/asyncHandler';

// Mounted at /businesses/:businessId/buyers — see index.ts
export const buyerRoutes = Router({ mergeParams: true });

buyerRoutes.use(requireAuth);

buyerRoutes.get(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const buyers = await buyerService.listForBusiness(req.params.businessId);
    res.json(buyers);
  }),
);

// Any member can add a buyer — low-stakes convenience entity, same
// precedent as units (not owner-only).
buyerRoutes.post(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const { name } = req.body;
    if (!name?.trim()) return res.status(400).json({ error: 'EMPTY_NAME' });

    try {
      const buyer = await buyerService.create(req.params.businessId, name);
      emitToBusiness(req.params.businessId, 'buyer:created', buyer);
      res.status(201).json(buyer);
    } catch (err: any) {
      if (err.message === 'EMPTY_NAME') return res.status(400).json({ error: 'EMPTY_NAME' });
      if (err.message === 'DUPLICATE_NAME') return res.status(409).json({ error: 'DUPLICATE_NAME' });
      throw err;
    }
  }),
);

buyerRoutes.get(
  '/:buyerId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const buyer = await buyerService.getById(req.params.businessId, req.params.buyerId);
    if (!buyer) return res.status(404).json({ error: 'BUYER_NOT_FOUND' });
    res.json(buyer);
  }),
);

// Filterable bill history for a buyer (Phase 8 §G) — query params:
// ?paid=true|false, ?dateFrom=ISO, ?dateTo=ISO (all optional).
buyerRoutes.get(
  '/:buyerId/bills',
  requireMembership,
  asyncHandler(async (req, res) => {
    const { paid, dateFrom, dateTo } = req.query;
    const bills = await billService.listForBuyer(req.params.businessId, req.params.buyerId, {
      paid: paid == null ? undefined : paid === 'true',
      dateFrom: dateFrom ? new Date(String(dateFrom)) : undefined,
      dateTo: dateTo ? new Date(String(dateTo)) : undefined,
    });
    res.json(bills);
  }),
);
