import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership, requireOwner } from '../middleware/businessAccess';
import { inventoryService } from '../services/inventoryService';
import { emitToBusiness } from '../sockets';
import { asyncHandler } from '../utils/asyncHandler';

// Mounted at /businesses/:businessId/items — see index.ts
export const inventoryRoutes = Router({ mergeParams: true });

inventoryRoutes.use(requireAuth);

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

inventoryRoutes.put(
  '/:itemId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const { name, price, quantity, unit } = req.body;
    if (!name?.trim() || price == null || quantity == null || !unit?.trim()) {
      return res.status(400).json({ error: 'name, price, quantity, unit are required' });
    }

    const item = await inventoryService.update(req.params.itemId, req.user!.id, {
      name: name.trim(),
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
  asyncHandler(async (req, res) => {
    await inventoryService.delete(req.params.itemId);
    emitToBusiness(req.params.businessId, 'item:deleted', { id: req.params.itemId });
    res.status(204).send();
  }),
);
