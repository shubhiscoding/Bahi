import { prisma } from '../prisma';

export const buyerService = {
  /**
   * Sorted by recency of last bill (most recently billed first), falling
   * back to createdAt for buyers with no bills yet — drives the buyer
   * picker's "top 4 by default" behavior (Phase 8 §E), same recency
   * spirit as the unit picker (Phase 7 §C), computed in JS since buyer
   * counts per business are small.
   */
  async listForBusiness(businessId: string) {
    const buyers = await prisma.buyer.findMany({
      where: { businessId },
      include: { bills: { orderBy: { billDate: 'desc' }, take: 1 } },
    });

    return buyers
      .map((b) => ({
        id: b.id,
        name: b.name,
        createdAt: b.createdAt,
        lastBilledAt: b.bills[0]?.billDate ?? null,
      }))
      .sort((a, b) => {
        const aTime = (a.lastBilledAt ?? a.createdAt).getTime();
        const bTime = (b.lastBilledAt ?? b.createdAt).getTime();
        return bTime - aTime;
      });
  },

  /**
   * Trims + rejects empty (400 EMPTY_NAME) + case-insensitive duplicate
   * check (409 DUPLICATE_NAME) scoped to this business only — buyer names
   * aren't shared vocabulary across businesses, unlike units.
   */
  async create(businessId: string, name: string) {
    const trimmed = name.trim();
    if (!trimmed) throw new Error('EMPTY_NAME');

    const existing = await prisma.buyer.findFirst({
      where: { businessId, name: { equals: trimmed, mode: 'insensitive' } },
    });
    if (existing) throw new Error('DUPLICATE_NAME');

    return prisma.buyer.create({ data: { businessId, name: trimmed } });
  },

  async getById(businessId: string, buyerId: string) {
    const buyer = await prisma.buyer.findFirst({
      where: { id: buyerId, businessId },
      include: { bills: { include: { payments: true } } },
    });
    if (!buyer) return null;

    let totalBilled = 0;
    let totalPaid = 0;
    for (const bill of buyer.bills) {
      totalBilled += Number(bill.total);
      for (const payment of bill.payments) {
        totalPaid += Number(payment.amount);
      }
    }

    return {
      id: buyer.id,
      name: buyer.name,
      createdAt: buyer.createdAt,
      totalBilled,
      totalPaid,
      totalDue: totalBilled - totalPaid,
    };
  },
};
