import { prisma } from '../prisma';

export interface ItemInput {
  name: string;
  price: number;
  quantity: number;
  unit: string;
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
    return prisma.inventoryItem.create({
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
  },

  async update(itemId: string, updatedBy: string, input: ItemInput) {
    return prisma.inventoryItem.update({
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
  },

  async delete(itemId: string) {
    await prisma.inventoryItem.delete({ where: { id: itemId } });
  },

  async getById(itemId: string) {
    return prisma.inventoryItem.findUnique({ where: { id: itemId } });
  },
};
