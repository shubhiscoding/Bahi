import { prisma } from '../prisma';

/**
 * Deposits (Phase 10) — the buyer-facing "जमा" view. Every payment,
 * whether recorded per-bill or allocated across several bills
 * oldest-first, wraps in exactly one Deposit (see billService.addPayment
 * / recordBuyerPayment). This service only reads; every write lives in
 * billService alongside the payment logic that creates these rows.
 */
export const depositService = {
  /** Business-wide receipt history for Hisab, including unlinked legacy allocations. */
  async listForBusiness(
    businessId: string,
    filters: { dateFrom?: Date; dateTo?: Date },
    sort: 'asc' | 'desc' = 'desc',
  ) {
    const paidAt = filters.dateFrom || filters.dateTo
      ? { gte: filters.dateFrom, lte: filters.dateTo }
      : undefined;
    const [deposits, legacyPayments] = await Promise.all([
      prisma.deposit.findMany({
        where: { businessId, ...(paidAt ? { paidAt } : {}) },
        include: { buyer: { select: { id: true, name: true } }, recorder: { select: { fullName: true } } },
        orderBy: [{ paidAt: sort }, { id: sort }],
      }),
      prisma.billPayment.findMany({
        where: {
          depositId: null,
          ...(paidAt ? { paidAt } : {}),
          bill: { is: { businessId } },
        },
        include: {
          bill: { include: { buyer: { select: { id: true, name: true } } } },
          recorder: { select: { fullName: true } },
        },
        orderBy: [{ paidAt: sort }, { id: sort }],
      }),
    ]);

    const events = [
      ...deposits.map((deposit) => ({
        id: deposit.id,
        depositId: deposit.id,
        amount: deposit.amount,
        paidAt: deposit.paidAt,
        buyerId: deposit.buyer.id,
        buyerName: deposit.buyer.name,
        recordedByName: deposit.recorder.fullName,
        legacy: false,
        billId: null as string | null,
      })),
      ...legacyPayments.map((payment) => ({
        id: `legacy:${payment.id}`,
        depositId: null,
        amount: payment.amount,
        paidAt: payment.paidAt,
        buyerId: payment.bill.buyer.id,
        buyerName: payment.bill.buyer.name,
        recordedByName: payment.recorder.fullName,
        legacy: true,
        billId: payment.billId,
      })),
    ];

    return events.sort((a, b) => {
      const dateOrder = a.paidAt.getTime() - b.paidAt.getTime();
      if (dateOrder !== 0) return sort === 'desc' ? -dateOrder : dateOrder;
      return sort === 'desc' ? b.id.localeCompare(a.id) : a.id.localeCompare(b.id);
    });
  },

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
