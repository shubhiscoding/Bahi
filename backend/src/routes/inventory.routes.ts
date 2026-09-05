import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership, requireOwner } from '../middleware/businessAccess';
import { inventoryService } from '../services/inventoryService';
import { prisma } from '../prisma';
import { emitToBusiness } from '../sockets';
import { asyncHandler } from '../utils/asyncHandler';
import { isFiniteNonNegativeNumber, isNonNegativeInteger, isPositiveInteger } from '../utils/validation';

// Mounted at /businesses/:businessId/items — see index.ts
export const inventoryRoutes = Router({ mergeParams: true });

inventoryRoutes.use(requireAuth);

// Defense-in-depth found while writing Phase 8's test suite: every
// :itemId route below previously trusted the itemId param without
// checking it actually belongs to :businessId — a member of business A
// could edit/delete/add-stock to an item from business B if they
// knew/guessed its ID, since requireMembership only checks membership in
// :businessId, not that :itemId is actually one of its items. Fixed here
// once, applied to every itemId-scoped route.
const requireItemInBusiness = asyncHandler(async (req, res, next) => {
  const item = await prisma.inventoryItem.findUnique({ where: { id: req.params.itemId } });
  if (!item || item.businessId !== req.params.businessId) {
    return res.status(404).json({ error: 'ITEM_NOT_FOUND' });
  }
  next();
});

inventoryRoutes.get(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const items = await inventoryService.list(req.params.businessId);
    res.json(items);
  }),
);

inventoryRoutes.post(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const { name, price, quantity, unit } = req.body;
    if (!name?.trim() || price == null || quantity == null || !unit?.trim()) {
      return res.status(400).json({ error: 'name, price, quantity, unit are required' });
    }
    // Phase 8 §A0 — presence alone isn't sanity; a negative price/quantity
    // was previously accepted outright.
    if (!isFiniteNonNegativeNumber(price)) {
      return res.status(400).json({ error: 'INVALID_PRICE' });
    }
    if (!isNonNegativeInteger(quantity)) {
      return res.status(400).json({ error: 'INVALID_QUANTITY' });
    }

    const item = await inventoryService.create(req.params.businessId, req.user!.id, {
      name: name.trim(),
      price: Number(price),
      quantity: Number(quantity),
      unit: unit.trim(),
    });

    emitToBusiness(req.params.businessId, 'item:created', item);
    res.status(201).json(item);
  }),
);

// Name is set once at creation and intentionally not editable afterward
// (confirmed decision) — this route no longer reads/accepts `name` at
// all, so even a direct API call (not just the UI) can't change it.
// Any `name` sent in the body is silently ignored, not rejected — a
// stale client sending its old unchanged value shouldn't hard-fail.
inventoryRoutes.put(
  '/:itemId',
  requireMembership,
  requireItemInBusiness,
  asyncHandler(async (req, res) => {
    const { price, quantity, unit } = req.body;
    if (price == null || quantity == null || !unit?.trim()) {
      return res.status(400).json({ error: 'price, quantity, unit are required' });
    }
    if (!isFiniteNonNegativeNumber(price)) {
      return res.status(400).json({ error: 'INVALID_PRICE' });
    }
    if (!isNonNegativeInteger(quantity)) {
      return res.status(400).json({ error: 'INVALID_QUANTITY' });
    }

    const item = await inventoryService.update(req.params.itemId, req.user!.id, {
      price: Number(price),
      quantity: Number(quantity),
      unit: unit.trim(),
    });

    emitToBusiness(req.params.businessId, 'item:updated', item);
    res.json(item);
  }),
);

inventoryRoutes.delete(
  '/:itemId',
  requireOwner,
  requireItemInBusiness,
  asyncHandler(async (req, res) => {
    try {
      await inventoryService.delete(req.params.itemId);
    } catch (err: any) {
      if (err.message === 'ITEM_HAS_BILLS') {
        return res.status(409).json({ error: 'ITEM_HAS_BILLS' });
      }
      throw err;
    }
    emitToBusiness(req.params.businessId, 'item:deleted', { id: req.params.itemId });
    res.status(204).send();
  }),
);

// Full price history, ascending — the item detail screen filters this into
// All-time/7-day/month windows client-side (Phase 7 §A).
inventoryRoutes.get(
  '/:itemId/price-history',
  requireMembership,
  requireItemInBusiness,
  asyncHandler(async (req, res) => {
    const history = await inventoryService.priceHistory(req.params.itemId);
    res.json(history);
  }),
);

// "Add stock" — pure quantity increment, doesn't touch price (Phase 8 §B).
inventoryRoutes.post(
  '/:itemId/add-stock',
  requireMembership,
  requireItemInBusiness,
  asyncHandler(async (req, res) => {
    const { quantity } = req.body;
    if (!isPositiveInteger(quantity)) {
      return res.status(400).json({ error: 'INVALID_QUANTITY' });
    }

    const item = await inventoryService.addStock(req.params.itemId, req.user!.id, Number(quantity));
    emitToBusiness(req.params.businessId, 'item:updated', item);
    res.json(item);
  }),
);

// Data pipe only — no UI consumes this yet (Phase 8 §A).
inventoryRoutes.get(
  '/:itemId/edit-log',
  requireMembership,
  requireItemInBusiness,
  asyncHandler(async (req, res) => {
    const log = await inventoryService.editLog(req.params.itemId);
    res.json(log);
  }),
);
