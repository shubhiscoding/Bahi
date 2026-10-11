import { prisma } from '../prisma';
import type { DateRangeFilter } from '../utils/dateRange';

type SortDirection = 'asc' | 'desc';

function billDateWhere(filters: DateRangeFilter) {
  return filters.dateFrom || filters.dateTo
    ? { billDate: { gte: filters.dateFrom, lte: filters.dateTo } }
    : {};
}

function paidDateWhere(filters: DateRangeFilter) {
  return filters.dateFrom || filters.dateTo
    ? { paidAt: { gte: filters.dateFrom, lte: filters.dateTo } }
    : {};
}

async function getBills(businessId: string, filters: DateRangeFilter, sort: SortDirection = 'desc') {
  return prisma.bill.findMany({
    where: { businessId, ...billDateWhere(filters) },
    include: {
      buyer: { select: { id: true, name: true } },
      payments: { select: { amount: true } },
      items: {
        select: {
          quantity: true,
          price: true,
          item: { select: { id: true, name: true } },
        },
      },
    },
    orderBy: [{ billDate: sort }, { id: sort }],
  });
}

function paymentTotal(bill: { payments: { amount: unknown }[] }) {
  return bill.payments.reduce((total, payment) => total + Number(payment.amount), 0);
}

function rankByAmount<T extends { id: string; name: string; amount: number }>(entries: Map<string, T>) {
  return [...entries.values()].sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name));
}

async function getPaymentTotals(businessId: string, filters: DateRangeFilter) {
  const [deposits, legacyPayments] = await Promise.all([
    prisma.deposit.aggregate({
      where: { businessId, ...paidDateWhere(filters) },
      _sum: { amount: true },
    }),
    prisma.billPayment.aggregate({
      where: {
        depositId: null,
        ...paidDateWhere(filters),
        bill: { is: { businessId } },
      },
      _sum: { amount: true },
    }),
  ]);

  return Number(deposits._sum.amount ?? 0) + Number(legacyPayments._sum.amount ?? 0);
}

export const dashboardService = {
  async getSummary(businessId: string, filters: DateRangeFilter) {
    const [bills, totalReceived] = await Promise.all([
      getBills(businessId, filters),
      getPaymentTotals(businessId, filters),
    ]);

    let totalBilled = 0;
    let totalDue = 0;
    const buyers = new Map<string, { id: string; name: string; amount: number }>();
    const products = new Map<string, { id: string; name: string; amount: number; quantity: number }>();

    for (const bill of bills) {
      const total = Number(bill.total);
      const paid = paymentTotal(bill);
      totalBilled += total;
      totalDue += Math.max(0, total - paid);

      const buyer = buyers.get(bill.buyer.id) ?? { id: bill.buyer.id, name: bill.buyer.name, amount: 0 };
      buyer.amount += total;
      buyers.set(buyer.id, buyer);

      for (const line of bill.items) {
        const product = products.get(line.item.id) ?? {
          id: line.item.id,
          name: line.item.name,
          amount: 0,
          quantity: 0,
        };
        product.amount += line.quantity * Number(line.price);
        product.quantity += line.quantity;
        products.set(product.id, product);
      }
    }

    return {
      totals: { totalBilled, totalDue, totalReceived },
      topBuyers: rankByAmount(buyers).slice(0, 3),
      topProducts: rankByAmount(products).slice(0, 3),
    };
  },

  async getRankings(businessId: string, filters: DateRangeFilter, kind: 'buyers' | 'products') {
    const bills = await getBills(businessId, filters);
    if (kind === 'buyers') {
      const buyers = new Map<string, { id: string; name: string; amount: number }>();
      for (const bill of bills) {
        const buyer = buyers.get(bill.buyer.id) ?? { id: bill.buyer.id, name: bill.buyer.name, amount: 0 };
        buyer.amount += Number(bill.total);
        buyers.set(buyer.id, buyer);
      }
      return rankByAmount(buyers);
    }

    const products = new Map<string, { id: string; name: string; amount: number; quantity: number }>();
    for (const bill of bills) {
      for (const line of bill.items) {
        const product = products.get(line.item.id) ?? {
          id: line.item.id,
          name: line.item.name,
          amount: 0,
          quantity: 0,
        };
        product.amount += line.quantity * Number(line.price);
        product.quantity += line.quantity;
        products.set(product.id, product);
      }
    }
    return rankByAmount(products);
  },
};
