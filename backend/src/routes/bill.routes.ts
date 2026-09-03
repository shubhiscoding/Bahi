import { Router } from 'express';
import { requireAuth } from '../middleware/auth';
import { requireMembership } from '../middleware/businessAccess';
import { billService } from '../services/billService';
import { inventoryService } from '../services/inventoryService';
import { prisma } from '../prisma';
import { emitToBusiness } from '../sockets';
import { asyncHandler } from '../utils/asyncHandler';
import { isFiniteNonNegativeNumber, isPositiveInteger } from '../utils/validation';

// Mounted at /businesses/:businessId/bills — see index.ts
export const billRoutes = Router({ mergeParams: true });

billRoutes.use(requireAuth);

billRoutes.post(
  '/',
  requireMembership,
  asyncHandler(async (req, res) => {
    const businessId = req.params.businessId;
    const { buyerId, billDate, items, markPaidNow } = req.body;

    if (!buyerId || typeof buyerId !== 'string') {
      return res.status(400).json({ error: 'BUYER_ID_REQUIRED' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'EMPTY_ITEMS' });
    }

    // Every line validated BEFORE anything is written — the whole
    // request is rejected together, no partial bill is ever created
    // (Phase 8 §D/§H).
    for (const line of items) {
      if (!line?.itemId || typeof line.itemId !== 'string') {
        return res.status(400).json({ error: 'INVALID_ITEM_ID' });
      }
      if (!isPositiveInteger(line.quantity)) {
        return res.status(400).json({ error: 'INVALID_QUANTITY' });
      }
      if (!isFiniteNonNegativeNumber(line.price)) {
        return res.status(400).json({ error: 'INVALID_PRICE' });
      }
    }

    // Defense-in-depth: every referenced buyer/item must actually belong
    // to this business — rejects cross-business IDs, same precedent as
    // every other route in this codebase.
    const buyer = await prisma.buyer.findFirst({ where: { id: buyerId, businessId } });
    if (!buyer) return res.status(400).json({ error: 'BUYER_NOT_FOUND' });

    const itemIds = [...new Set(items.map((l: any) => l.itemId))];
    const foundItems = await prisma.inventoryItem.findMany({
      where: { id: { in: itemIds }, businessId },
    });
    if (foundItems.length !== itemIds.length) {
      return res.status(400).json({ error: 'ITEM_NOT_FOUND' });
    }

    const bill = await billService.create(businessId, req.user!.id, {
      buyerId,
      billDate: billDate ? new Date(billDate) : new Date(),
      items: items.map((l: any) => ({
        itemId: l.itemId,
        quantity: Number(l.quantity),
        price: Number(l.price),
      })),
      markPaidNow: Boolean(markPaidNow),
    });

    emitToBusiness(businessId, 'bill:created', bill);
    // Emit the FULL item, not just its id — the Flutter socket handler
    // (InventoryRepository.onUpdated) parses whatever payload arrives
    // straight into a full InventoryItem via fromJson, defaulting every
    // missing field (name '', price 0, quantity 0, unit 'piece') and
    // overwriting the real item in the live list with that blank stub.
    // This was a real bug, not a display filter — negative quantity
    // itself is allowed (billing more than stock, by design); only a
    // partial payload was the problem.
    for (const itemId of itemIds) {
      const item = await inventoryService.getById(itemId);
      if (item) emitToBusiness(businessId, 'item:updated', item);
    }
    res.status(201).json(bill);
  }),
);

billRoutes.get(
  '/:billId',
  requireMembership,
  asyncHandler(async (req, res) => {
    const bill = await billService.getById(req.params.businessId, req.params.billId);
    if (!bill) return res.status(404).json({ error: 'BILL_NOT_FOUND' });
    res.json(bill);
  }),
);

billRoutes.post(
  '/:billId/payments',
  requireMembership,
  asyncHandler(async (req, res) => {
    const { amount } = req.body;
    if (!isFiniteNonNegativeNumber(amount) || Number(amount) <= 0) {
      return res.status(400).json({ error: 'INVALID_AMOUNT' });
    }

    try {
      const payment = await billService.addPayment(
        req.params.businessId,
        req.params.billId,
        req.user!.id,
        Number(amount),
      );
      emitToBusiness(req.params.businessId, 'bill:updated', { id: req.params.billId });
      res.status(201).json(payment);
    } catch (err: any) {
      if (err.message === 'BILL_NOT_FOUND') return res.status(404).json({ error: 'BILL_NOT_FOUND' });
      if (err.message === 'OVERPAYMENT') return res.status(400).json({ error: 'OVERPAYMENT' });
      throw err;
    }
  }),
);
