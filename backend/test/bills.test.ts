import { describe, it, expect, beforeAll, vi } from 'vitest';
import request from 'supertest';
import { prisma } from '../src/prisma';

// Spy on emitToBusiness to catch the exact regression this test guards:
// billing used to broadcast item:updated with only { id }, which the
// Flutter client parses straight into a full InventoryItem, defaulting
// every missing field and blanking out the real item in the live list.
const emitSpy = vi.fn();
vi.mock('../src/sockets', () => ({ emitToBusiness: (...args: unknown[]) => emitSpy(...args) }));

const { app, authHeader, makeTestBusiness, makeTestItem } = await import('./helpers');

describe('bills', () => {
  let businessId: string;
  let ownerId: string;
  let buyerId: string;

  beforeAll(async () => {
    ({ businessId, ownerId } = await makeTestBusiness());
    const buyer = await prisma.buyer.create({ data: { businessId, name: 'Bill Test Buyer' } });
    buyerId = buyer.id;
  });

  describe('POST /businesses/:id/bills — validation, nothing partially written on rejection', () => {
    it('rejects an empty items array', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('EMPTY_ITEMS');
    });

    it('rejects a negative line-item quantity, and creates no bill at all', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const before = await prisma.bill.count({ where: { businessId } });

      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: -1, price: 10 }] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');

      const after = await prisma.bill.count({ where: { businessId } });
      expect(after).toBe(before);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(100); // untouched
    });

    it('rejects a zero line-item quantity', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 0, price: 10 }] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('rejects a negative line-item price', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 1, price: -5 }] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_PRICE');
    });

    it('rejects a buyer that does not belong to this business', async () => {
      const other = await makeTestBusiness();
      const otherBuyer = await prisma.buyer.create({ data: { businessId: other.businessId, name: 'Other Buyer' } });
      const item = await makeTestItem(businessId, ownerId);

      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId: otherBuyer.id, items: [{ itemId: item.id, quantity: 1, price: 10 }] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('BUYER_NOT_FOUND');
    });

    it('rejects an item that does not belong to this business', async () => {
      const other = await makeTestBusiness();
      const otherItem = await makeTestItem(other.businessId, other.ownerId);

      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: otherItem.id, quantity: 1, price: 10 }] });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('ITEM_NOT_FOUND');
    });
  });

  describe('POST /businesses/:id/bills — happy path + side effects', () => {
    it('creates a bill with 2 line items, decrements both items stock, logs one edit-log row each', async () => {
      const itemA = await makeTestItem(businessId, ownerId, { name: 'A', quantity: 50, price: 10 });
      const itemB = await makeTestItem(businessId, ownerId, { name: 'B', quantity: 30, price: 20 });

      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({
          buyerId,
          items: [
            { itemId: itemA.id, quantity: 5, price: 10 },
            { itemId: itemB.id, quantity: 2, price: 20 },
          ],
          markPaidNow: false,
        });
      expect(res.status).toBe(201);
      expect(Number(res.body.total)).toBe(90); // 5*10 + 2*20

      const refreshedA = await prisma.inventoryItem.findUnique({ where: { id: itemA.id } });
      const refreshedB = await prisma.inventoryItem.findUnique({ where: { id: itemB.id } });
      expect(refreshedA!.quantity).toBe(45);
      expect(refreshedB!.quantity).toBe(28);

      const logA = await request(app)
        .get(`/businesses/${businessId}/items/${itemA.id}/edit-log`)
        .set('Authorization', authHeader(ownerId));
      expect(logA.body).toHaveLength(1);
      expect(logA.body[0].source).toBe('sale');
      expect(logA.body[0].relatedBillId).toBe(res.body.id);

      // The regression this guards: item:updated must carry the FULL
      // item (name/price/unit intact), not just { id } — a partial
      // payload gets parsed straight into a blank InventoryItem
      // client-side and overwrites the real item in the live list.
      const itemUpdateCallA = emitSpy.mock.calls.find(
        (call) => call[1] === 'item:updated' && call[2]?.id === itemA.id,
      );
      expect(itemUpdateCallA).toBeTruthy();
      expect(itemUpdateCallA![2].name).toBe('A');
      expect(Number(itemUpdateCallA![2].price)).toBe(10);
      expect(itemUpdateCallA![2].quantity).toBe(45);
    });

    it('billing more than current stock is allowed (goes negative — no hard block)', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 2 });
      const res = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 10, price: 5 }] });
      expect(res.status).toBe(201);

      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(-8);
    });

    it('markPaidNow creates one payment covering the full total; due is 0', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 20 });
      const create = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 3, price: 10 }], markPaidNow: true });

      const detail = await request(app)
        .get(`/businesses/${businessId}/bills/${create.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(detail.body.due).toBe(0);
      expect(detail.body.paid).toBe(30);
    });

    it('markPaidNow also creates a matching deposit — the exact regression reported after Phase 10 shipped (bills showed paid with no deposit)', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 20 });
      const create = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 2, price: 25 }], markPaidNow: true });

      const deposits = await request(app)
        .get(`/businesses/${businessId}/buyers/${buyerId}/deposits`)
        .set('Authorization', authHeader(ownerId));
      const matching = deposits.body.find((d: any) => Number(d.amount) === 50);
      expect(matching).toBeTruthy();

      const depositDetail = await request(app)
        .get(`/businesses/${businessId}/deposits/${matching.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(depositDetail.body.bills).toHaveLength(1);
      expect(depositDetail.body.bills[0].billId).toBe(create.body.id);
    });

    it('unpaid bill has full due, zero paid', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 20 });
      const create = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 3, price: 10 }], markPaidNow: false });

      const detail = await request(app)
        .get(`/businesses/${businessId}/bills/${create.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(detail.body.due).toBe(30);
      expect(detail.body.paid).toBe(0);
    });
  });

  describe('POST /businesses/:id/bills/:billId/payments — partial payments', () => {
    it('rejects zero/negative amount', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const bill = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 1, price: 100 }] });

      const zero = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 0 });
      expect(zero.status).toBe(400);

      const negative = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: -10 });
      expect(negative.status).toBe(400);
    });

    it('rejects an amount greater than the remaining due', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const bill = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 1, price: 100 }] });

      const res = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 150 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('OVERPAYMENT');
    });

    it('supports a partial payment, then the remainder, reaching due = 0', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const bill = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 1, price: 100 }] });

      const partial = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 40 });
      expect(partial.status).toBe(201);

      const midDetail = await request(app)
        .get(`/businesses/${businessId}/bills/${bill.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(midDetail.body.due).toBe(60);

      const rest = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 60 });
      expect(rest.status).toBe(201);

      const finalDetail = await request(app)
        .get(`/businesses/${businessId}/bills/${bill.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(finalDetail.body.due).toBe(0);
    });

    it('bill detail lists every payment with amount, date, and who recorded it', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const bill = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId, items: [{ itemId: item.id, quantity: 1, price: 100 }] });

      // recordedByName is joined from the profiles table (Test Owner, per
      // makeTestBusiness), NOT the auth header's fullName claim — that
      // claim only sets req.user in-memory for the test bypass, it never
      // writes back to the profile row.
      await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 40 });

      const detail = await request(app)
        .get(`/businesses/${businessId}/bills/${bill.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(detail.body.payments).toHaveLength(1);
      expect(Number(detail.body.payments[0].amount)).toBe(40);
      expect(detail.body.payments[0].recordedByName).toBe('Test Owner');
      expect(detail.body.payments[0].paidAt).toBeTruthy();
    });
  });

  describe('buyer aggregates reflect bills + payments', () => {
    it('totalBilled/totalPaid/totalDue add up correctly across multiple bills', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Agg Buyer' } });
      const item = await makeTestItem(business.businessId, business.ownerId, { quantity: 100 });

      await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 1, price: 100 }], markPaidNow: true });
      await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 1, price: 50 }], markPaidNow: false });

      const detail = await request(app)
        .get(`/businesses/${business.businessId}/buyers/${buyer.id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(detail.body.totalBilled).toBe(150);
      expect(detail.body.totalPaid).toBe(100);
      expect(detail.body.totalDue).toBe(50);
    });
  });

  describe('POST /businesses/:id/buyers/:buyerId/payments — oldest-first allocation (Phase 9)', () => {
    async function makeAgedBills(businessId: string, ownerId: string, buyerId: string) {
      const item = await makeTestItem(businessId, ownerId, { quantity: 1000 });
      const dues = [80, 30, 20]; // oldest to newest
      const bills = [];
      for (let i = 0; i < dues.length; i++) {
        const billDate = new Date(Date.now() - (dues.length - i) * 24 * 60 * 60 * 1000).toISOString();
        const res = await request(app)
          .post(`/businesses/${businessId}/bills`)
          .set('Authorization', authHeader(ownerId))
          .send({ buyerId, billDate, items: [{ itemId: item.id, quantity: 1, price: dues[i] }] });
        bills.push(res.body);
      }
      return bills; // [oldest(80), middle(30), newest(20)]
    }

    it('fills the oldest bill fully, then partially fills the next, leaving the rest untouched', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Aged Buyer' } });
      const [oldest, middle, newest] = await makeAgedBills(business.businessId, business.ownerId, buyer.id);

      const res = await request(app)
        .post(`/businesses/${business.businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 95 }); // 80 (fills oldest) + 15 (partial on middle)
      expect(res.status).toBe(201);
      expect(res.body).toHaveLength(2); // only 2 bills touched

      const oldestDetail = await request(app)
        .get(`/businesses/${business.businessId}/bills/${oldest.id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(oldestDetail.body.due).toBe(0);

      const middleDetail = await request(app)
        .get(`/businesses/${business.businessId}/bills/${middle.id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(middleDetail.body.due).toBe(15); // 30 - 15

      const newestDetail = await request(app)
        .get(`/businesses/${business.businessId}/bills/${newest.id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(newestDetail.body.due).toBe(20); // untouched
    });

    it('rejects an amount greater than the total outstanding due, writing nothing', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Overpay Buyer' } });
      const [oldest] = await makeAgedBills(business.businessId, business.ownerId, buyer.id);

      const res = await request(app)
        .post(`/businesses/${business.businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 1000 }); // total due is 80+30+20=130
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('OVERPAYMENT');

      const oldestDetail = await request(app)
        .get(`/businesses/${business.businessId}/bills/${oldest.id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(oldestDetail.body.due).toBe(80); // untouched
    });

    it('rejects when the buyer has nothing due', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'PaidUp Buyer' } });
      const item = await makeTestItem(business.businessId, business.ownerId);
      await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 1, price: 50 }], markPaidNow: true });

      const res = await request(app)
        .post(`/businesses/${business.businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 10 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('NOTHING_DUE');
    });

    it('exact total due fully pays off every bill', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'ExactPay Buyer' } });
      const [oldest, middle, newest] = await makeAgedBills(business.businessId, business.ownerId, buyer.id);

      const res = await request(app)
        .post(`/businesses/${business.businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 130 });
      expect(res.status).toBe(201);
      expect(res.body).toHaveLength(3);

      for (const bill of [oldest, middle, newest]) {
        const detail = await request(app)
          .get(`/businesses/${business.businessId}/bills/${bill.id}`)
          .set('Authorization', authHeader(business.ownerId));
        expect(detail.body.due).toBe(0);
      }
    });
  });

  describe('Deposits (Phase 10) — every payment wraps in exactly one Deposit', () => {
    it('a single-bill payment creates one deposit with one settled bill', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Single Deposit Buyer' } });
      const item = await makeTestItem(business.businessId, business.ownerId);
      const bill = await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 1, price: 100 }] });

      await request(app)
        .post(`/businesses/${business.businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 40 });

      const deposits = await request(app)
        .get(`/businesses/${business.businessId}/buyers/${buyer.id}/deposits`)
        .set('Authorization', authHeader(business.ownerId));
      expect(deposits.body).toHaveLength(1);
      expect(Number(deposits.body[0].amount)).toBe(40);

      const detail = await request(app)
        .get(`/businesses/${business.businessId}/deposits/${deposits.body[0].id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(detail.body.bills).toHaveLength(1);
      expect(detail.body.bills[0].billId).toBe(bill.body.id);
      expect(Number(detail.body.bills[0].amount)).toBe(40);
    });

    it('a buyer-level payment spanning 2 bills creates ONE deposit with two settled bills summing to its amount', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Multi Deposit Buyer' } });
      const item = await makeTestItem(business.businessId, business.ownerId, { quantity: 1000 });

      const older = await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({
          buyerId: buyer.id,
          billDate: new Date(Date.now() - 2 * 86400000).toISOString(),
          items: [{ itemId: item.id, quantity: 1, price: 80 }],
        });
      const newer = await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({
          buyerId: buyer.id,
          billDate: new Date(Date.now() - 1 * 86400000).toISOString(),
          items: [{ itemId: item.id, quantity: 1, price: 30 }],
        });

      await request(app)
        .post(`/businesses/${business.businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 95 }); // fills older (80) + partial on newer (15)

      const deposits = await request(app)
        .get(`/businesses/${business.businessId}/buyers/${buyer.id}/deposits`)
        .set('Authorization', authHeader(business.ownerId));
      expect(deposits.body).toHaveLength(1); // ONE deposit, not two
      expect(Number(deposits.body[0].amount)).toBe(95);

      const detail = await request(app)
        .get(`/businesses/${business.businessId}/deposits/${deposits.body[0].id}`)
        .set('Authorization', authHeader(business.ownerId));
      expect(detail.body.bills).toHaveLength(2);
      const sum = detail.body.bills.reduce((s: number, b: any) => s + Number(b.amount), 0);
      expect(sum).toBe(95);
      const olderRow = detail.body.bills.find((b: any) => b.billId === older.body.id);
      const newerRow = detail.body.bills.find((b: any) => b.billId === newer.body.id);
      expect(Number(olderRow.amount)).toBe(80);
      expect(Number(newerRow.amount)).toBe(15);
    });

    it('deposits list is sorted latest-first', async () => {
      const business = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: business.businessId, name: 'Sorted Deposit Buyer' } });
      const item = await makeTestItem(business.businessId, business.ownerId, { quantity: 1000 });
      const bill = await request(app)
        .post(`/businesses/${business.businessId}/bills`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 10, price: 100 }] });

      await request(app)
        .post(`/businesses/${business.businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 10 });
      await request(app)
        .post(`/businesses/${business.businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(business.ownerId))
        .send({ amount: 20 });

      const deposits = await request(app)
        .get(`/businesses/${business.businessId}/buyers/${buyer.id}/deposits`)
        .set('Authorization', authHeader(business.ownerId));
      expect(deposits.body).toHaveLength(2);
      expect(Number(deposits.body[0].amount)).toBe(20); // most recent first
      expect(Number(deposits.body[1].amount)).toBe(10);
    });

    it('a deposit belonging to another business is 404, not leaked', async () => {
      const businessA = await makeTestBusiness();
      const businessB = await makeTestBusiness();
      const buyer = await prisma.buyer.create({ data: { businessId: businessA.businessId, name: 'Isolation Buyer' } });
      const item = await makeTestItem(businessA.businessId, businessA.ownerId);
      const bill = await request(app)
        .post(`/businesses/${businessA.businessId}/bills`)
        .set('Authorization', authHeader(businessA.ownerId))
        .send({ buyerId: buyer.id, items: [{ itemId: item.id, quantity: 1, price: 50 }] });
      await request(app)
        .post(`/businesses/${businessA.businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(businessA.ownerId))
        .send({ amount: 50 });

      const deposits = await request(app)
        .get(`/businesses/${businessA.businessId}/buyers/${buyer.id}/deposits`)
        .set('Authorization', authHeader(businessA.ownerId));
      const depositId = deposits.body[0].id;

      const res = await request(app)
        .get(`/businesses/${businessB.businessId}/deposits/${depositId}`)
        .set('Authorization', authHeader(businessB.ownerId));
      expect(res.status).toBe(404);
    });
  });
});
