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

    // Only record a new history point when the price actually changed —
    // confirmed decision, not on every save (Phase 7 §A).
    if (existing && Number(existing.price) !== Number(item.price)) {
      await prisma.inventoryPriceHistory.create({
        data: { itemId: item.id, price: item.price, editedBy: updatedBy },
      });
    }
    await touchUnitLastUsed(item.businessId, input.unit);

    return item;
  },

  async delete(itemId: string) {
    await prisma.inventoryItem.delete({ where: { id: itemId } });
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
};
