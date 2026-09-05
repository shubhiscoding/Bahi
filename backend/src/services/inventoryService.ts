import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';

export interface ItemInput {
  name: string;
  price: number;
  quantity: number;
  unit: string;
}

/**
 * Touches BusinessUnit.lastUsedAt for the given unit name, if it's linked
 * to this business — drives the unit picker's recency sort (Phase 7 §C).
 * Silently no-ops if the unit isn't linked (e.g. a stale/unknown string);
 * item saves should never fail because of this bookkeeping.
 */
async function touchUnitLastUsed(businessId: string, unitName: string) {
  const unit = await prisma.unit.findUnique({ where: { name: unitName } });
  if (!unit) return;
  await prisma.businessUnit.updateMany({
    where: { businessId, unitId: unit.id },
    data: { lastUsedAt: new Date() },
  });
}

type Changes = Record<string, { from: unknown; to: unknown }>;

/**
 * Builds the { field: { from, to } } diff for every field that actually
 * changed between the item's prior state and its new input — feeds
 * InventoryEditLog (Phase 8 §A). Returns an empty object for a no-op save
 * (nothing changed), in which case the caller writes no log row at all.
 */
function diffItemFields(
  existing: { name: string; price: unknown; quantity: number; unit: string },
  input: ItemInput,
): Changes {
  const changes: Changes = {};
  if (existing.name !== input.name) {
    changes.name = { from: existing.name, to: input.name };
  }
  if (Number(existing.price) !== Number(input.price)) {
    changes.price = { from: existing.price, to: input.price };
  }
  if (existing.quantity !== input.quantity) {
    changes.quantity = { from: existing.quantity, to: input.quantity };
  }
  if (existing.unit !== input.unit) {
    changes.unit = { from: existing.unit, to: input.unit };
  }
  return changes;
}

export const inventoryService = {
  async list(businessId: string) {
    return prisma.inventoryItem.findMany({
      where: { businessId },
      orderBy: { name: 'asc' },
    });
  },

  // updated_by/updated_at are ALWAYS set server-side here — this is the
  // hard requirement carried over from the original plan (§9): no write
  // path may ever create/update a row without stamping who and when.
  async create(businessId: string, updatedBy: string, input: ItemInput) {
    const item = await prisma.inventoryItem.create({
      data: {
        businessId,
        name: input.name,
        price: input.price,
        quantity: input.quantity,
        unit: input.unit,
        updatedBy,
        updatedAt: new Date(),
      },
    });

    // Seed the price history with the starting price (Phase 7 §A).
    await prisma.inventoryPriceHistory.create({
      data: { itemId: item.id, price: item.price, editedBy: updatedBy },
    });
    await touchUnitLastUsed(businessId, input.unit);

    return item;
  },

  async update(itemId: string, updatedBy: string, input: ItemInput) {
    const existing = await prisma.inventoryItem.findUnique({ where: { id: itemId } });

    const item = await prisma.inventoryItem.update({
      where: { id: itemId },
      data: {
        name: input.name,
        price: input.price,
        quantity: input.quantity,
        unit: input.unit,
        updatedBy,
        updatedAt: new Date(),
      },
    });

    if (existing) {
      // Only record a new price-history point when the price actually
      // changed — confirmed decision, not on every save (Phase 7 §A).
      if (Number(existing.price) !== Number(item.price)) {
        await prisma.inventoryPriceHistory.create({
          data: { itemId: item.id, price: item.price, editedBy: updatedBy },
        });
      }

      // General edit-audit log (Phase 8 §A) — every field that changed,
      // not just price. A no-op save (nothing changed) writes no row.
      const changes = diffItemFields(existing, input);
      if (Object.keys(changes).length > 0) {
        await prisma.inventoryEditLog.create({
          data: {
            itemId: item.id,
            editedBy: updatedBy,
            source: 'edit',
            changes: changes as Prisma.InputJsonValue,
          },
        });
      }
    }

    await touchUnitLastUsed(item.businessId, input.unit);

    return item;
  },

  /**
   * Pure quantity increment — the "add stock" CTA (Phase 8 §B). Doesn't
   * touch price/InventoryPriceHistory; logs to InventoryEditLog with
   * source: 'restock' so future UI can tell this apart from a manual edit.
   */
  async addStock(itemId: string, updatedBy: string, addQuantity: number) {
    const existing = await prisma.inventoryItem.findUniqueOrThrow({ where: { id: itemId } });

    const item = await prisma.inventoryItem.update({
      where: { id: itemId },
      data: {
        quantity: { increment: addQuantity },
        updatedBy,
        updatedAt: new Date(),
      },
    });

    await prisma.inventoryEditLog.create({
      data: {
        itemId: item.id,
        editedBy: updatedBy,
        source: 'restock',
        changes: { quantity: { from: existing.quantity, to: item.quantity } },
      },
    });

    return item;
  },

  /**
   * BillItem.item is onDelete: Restrict (deliberate — protects sale
   * history), so Postgres rejects this delete with FK error P2003 once
   * an item has ever been billed. Without catching it specifically here,
   * that error fell through to app.ts's generic 500 handler and the
   * Flutter client showed a raw, meaningless message instead of a real
   * "this item has been billed and can't be deleted" — the exact bug
   * reported after this route shipped.
   */
  async delete(itemId: string) {
    try {
      await prisma.inventoryItem.delete({ where: { id: itemId } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2003') {
        throw new Error('ITEM_HAS_BILLS');
      }
      throw e;
    }
  },

  async getById(itemId: string) {
    return prisma.inventoryItem.findUnique({ where: { id: itemId } });
  },

  async priceHistory(itemId: string) {
    const rows = await prisma.inventoryPriceHistory.findMany({
      where: { itemId },
      include: { editor: true },
      orderBy: { recordedAt: 'asc' },
    });

    // Flatten the join (same pattern as businessService.listMembers) —
    // editedBy/editor are null on rows written before this column existed
    // (no backfill), so editedByName falls back to null, not an error.
    return rows.map((r) => ({
      id: r.id,
      price: r.price,
      recordedAt: r.recordedAt,
      editedBy: r.editedBy,
      editedByName: r.editor?.fullName ?? null,
    }));
  },

  /** Phase 8 §A — data pipe only, no UI consumes this yet. */
  async editLog(itemId: string) {
    const rows = await prisma.inventoryEditLog.findMany({
      where: { itemId },
      include: { editor: true },
      orderBy: { editedAt: 'desc' },
    });

    return rows.map((r) => ({
      id: r.id,
      editedAt: r.editedAt,
      editedBy: r.editedBy,
      editedByName: r.editor.fullName,
      source: r.source,
      changes: r.changes,
      relatedBillId: r.relatedBillId,
    }));
  },
};
