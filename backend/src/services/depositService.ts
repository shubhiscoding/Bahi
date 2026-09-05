import { prisma } from '../prisma';

/**
 * Deposits (Phase 10) — the buyer-facing "जमा" view. Every payment,
 * whether recorded per-bill or allocated across several bills
 * oldest-first, wraps in exactly one Deposit (see billService.addPayment
 * / recordBuyerPayment). This service only reads; every write lives in
 * billService alongside the payment logic that creates these rows.
 */
export const depositService = {
  /** Feeds the buyer detail page's जमा list — latest first. */
  async listForBuyer(
    businessId: string,
    buyerId: string,
    filters: { dateFrom?: Date; dateTo?: Date },
  ) {
    const deposits = await prisma.deposit.findMany({
      where: {
        businessId,
        buyerId,
        paidAt: {
          gte: filters.dateFrom,
          lte: filters.dateTo,
        },
      },
      include: { recorder: true },
      orderBy: { paidAt: 'desc' },
    });

    return deposits.map((d) => ({
      id: d.id,
      amount: d.amount,
      paidAt: d.paidAt,
      recordedByName: d.recorder.fullName,
    }));
  },

  /** Deposit detail — total + which bills it settled and how much each got. */
  async getById(businessId: string, depositId: string) {
    const deposit = await prisma.deposit.findFirst({
      where: { id: depositId, businessId },
      include: {
        recorder: true,
        payments: { include: { bill: true }, orderBy: { paidAt: 'asc' } },
      },
    });
    if (!deposit) return null;

    return {
      id: deposit.id,
      amount: deposit.amount,
      paidAt: deposit.paidAt,
      recordedByName: deposit.recorder.fullName,
      bills: deposit.payments.map((p) => ({
        billId: p.billId,
        billDate: p.bill.billDate,
        billTotal: p.bill.total,
        amount: p.amount, // how much of THIS deposit applied to this bill
      })),
    };
  },
};
