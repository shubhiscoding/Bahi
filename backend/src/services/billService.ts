import type { Prisma } from '@prisma/client';
import { prisma } from '../prisma';

export interface BillLineInput {
  itemId: string;
  quantity: number;
  price: number;
}

export interface CreateBillInput {
  buyerId: string;
  billDate: Date;
  items: BillLineInput[];
  markPaidNow: boolean;
}

function billWithDue<T extends { total: Prisma.Decimal | number; payments: { amount: Prisma.Decimal | number }[] }>(
  bill: T,
) {
  const paid = bill.payments.reduce((sum, p) => sum + Number(p.amount), 0);
  return { ...bill, paid, due: Number(bill.total) - paid };
}

export const billService = {
  /**
   * One transaction: create the bill + its line items, decrement each
   * referenced item's stock, log one InventoryEditLog row per affected
   * item (source: 'sale'), and optionally record an initial full payment.
   * Every validation happens BEFORE the transaction starts, in the route
   * (Phase 8 §D) — nothing here should ever partially apply.
   */
  async create(businessId: string, createdBy: string, input: CreateBillInput) {
    const total = input.items.reduce((sum, line) => sum + line.quantity * line.price, 0);

    return prisma.$transaction(async (tx) => {
      const bill = await tx.bill.create({
        data: {
          businessId,
          buyerId: input.buyerId,
          billDate: input.billDate,
          total,
          createdBy,
        },
      });

      for (const line of input.items) {
        await tx.billItem.create({
          data: {
            billId: bill.id,
            itemId: line.itemId,
            quantity: line.quantity,
            price: line.price,
          },
        });

        const existing = await tx.inventoryItem.findUniqueOrThrow({ where: { id: line.itemId } });
        const item = await tx.inventoryItem.update({
          where: { id: line.itemId },
          data: { quantity: { decrement: line.quantity }, updatedBy: createdBy, updatedAt: new Date() },
        });
        await tx.inventoryEditLog.create({
          data: {
            itemId: item.id,
            editedBy: createdBy,
            source: 'sale',
            relatedBillId: bill.id,
            changes: { quantity: { from: existing.quantity, to: item.quantity } },
          },
        });
      }

      if (input.markPaidNow) {
        await tx.billPayment.create({
          data: { billId: bill.id, amount: total, recordedBy: createdBy },
        });
      }

      return tx.bill.findUniqueOrThrow({
        where: { id: bill.id },
        include: { items: true, payments: true, buyer: true },
      });
    });
  },

  async getById(businessId: string, billId: string) {
    const bill = await prisma.bill.findFirst({
      where: { id: billId, businessId },
      include: {
        buyer: true,
        creator: true,
        payments: { orderBy: { paidAt: 'asc' }, include: { recorder: true } },
        items: { include: { item: true } },
      },
    });
    if (!bill) return null;

    return {
      ...billWithDue(bill),
      buyerName: bill.buyer.name,
      createdByName: bill.creator.fullName,
      items: bill.items.map((i) => ({
        id: i.id,
        itemId: i.itemId,
        itemName: i.item.name,
        quantity: i.quantity,
        price: i.price,
      })),
      // Flatten the recorder join — same pattern as priceHistory/editLog
      // — so the bill detail screen can list who recorded each payment
      // without a separate lookup.
      payments: bill.payments.map((p) => ({
        id: p.id,
        amount: p.amount,
        paidAt: p.paidAt,
        recordedByName: p.recorder.fullName,
      })),
    };
  },

  /** Feeds the buyer detail page's filterable bill list (Phase 8 §G). */
  async listForBuyer(
    businessId: string,
    buyerId: string,
    filters: { paid?: boolean; dateFrom?: Date; dateTo?: Date },
  ) {
    const bills = await prisma.bill.findMany({
      where: {
        businessId,
        buyerId,
        billDate: {
          gte: filters.dateFrom,
          lte: filters.dateTo,
        },
      },
      include: { payments: true },
      orderBy: { billDate: 'desc' },
    });

    const withDue = bills.map(billWithDue);
    if (filters.paid == null) return withDue;
    return withDue.filter((b) => (filters.paid ? b.due <= 0 : b.due > 0));
  },

  /**
   * Records a (possibly partial) payment. Rejects overpayment beyond the
   * remaining due (400 OVERPAYMENT) — a due balance should never go
   * negative/nonsensical (Phase 8 §D/§H).
   */
  async addPayment(businessId: string, billId: string, recordedBy: string, amount: number) {
    const bill = await prisma.bill.findFirst({
      where: { id: billId, businessId },
      include: { payments: true },
    });
    if (!bill) throw new Error('BILL_NOT_FOUND');

    const paidSoFar = bill.payments.reduce((sum, p) => sum + Number(p.amount), 0);
    const due = Number(bill.total) - paidSoFar;
    if (amount > due) throw new Error('OVERPAYMENT');

    return prisma.billPayment.create({
      data: { billId, amount, recordedBy },
    });
  },

  /**
   * Buyer-level "record payment" (Phase 9) — allocates one total amount
   * across the buyer's outstanding bills, oldest billDate first, filling
   * each bill's remaining due completely before moving to the next. The
   * last bill touched may only get a partial amount if it doesn't fully
   * cover that bill's due. One BillPayment row per bill actually touched
   * — same table the per-bill "record payment" flow writes to, so each
   * bill's own payments-made list correctly reflects this.
   *
   * Whole-request validation happens before any row is written — either
   * the full amount gets allocated, or nothing does.
   */
  async recordBuyerPayment(businessId: string, buyerId: string, recordedBy: string, amount: number) {
    const bills = await prisma.bill.findMany({
      where: { businessId, buyerId },
      include: { payments: true },
      orderBy: { billDate: 'asc' },
    });

    const outstanding = bills.map(billWithDue).filter((b) => b.due > 0);
    if (outstanding.length === 0) throw new Error('NOTHING_DUE');

    const totalDue = outstanding.reduce((sum, b) => sum + b.due, 0);
    if (amount > totalDue) throw new Error('OVERPAYMENT');

    return prisma.$transaction(async (tx) => {
      let remaining = amount;
      const created = [];
      for (const bill of outstanding) {
        if (remaining <= 0) break;
        const allocation = Math.min(remaining, bill.due);
        const payment = await tx.billPayment.create({
          data: { billId: bill.id, amount: allocation, recordedBy },
        });
        created.push(payment);
        remaining -= allocation;
      }
      return created;
    });
  },
};
