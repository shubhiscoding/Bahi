import { describe, it, expect, beforeAll, vi } from 'vitest';
import request from 'supertest';
import { prisma } from '../src/prisma';

// Socket broadcasts are not under test here; spy so no real socket is needed.
const emitSpy = vi.fn();
vi.mock('../src/sockets', () => ({ emitToBusiness: (...args: unknown[]) => emitSpy(...args) }));

const { app, authHeader, makeTestBusiness, makeTestItem } = await import('./helpers');

describe('payment and bill dates (paidAt)', () => {
  let businessId: string;
  let ownerId: string;
  let buyerId: string;

  beforeAll(async () => {
    ({ businessId, ownerId } = await makeTestBusiness());
    const buyer = await prisma.buyer.create({ data: { businessId, name: 'Date Test Buyer' } });
    buyerId = buyer.id;
  });

  const createBill = (body: object) =>
    request(app)
      .post(`/businesses/${businessId}/bills`)
      .set('Authorization', authHeader(ownerId))
      .send(body);

  const billLine = (itemId: string, quantity = 1, price = 10) => [{ itemId, quantity, price }];

  describe('bill created with an initial payment', () => {
    it('markPaidNow: the payment and its deposit take the bill date, not the save time', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const billDate = '2026-03-15T00:00:00.000Z';

      const res = await createBill({
        buyerId,
        billDate,
        items: billLine(item.id),
        markPaidNow: true,
      });
      expect(res.status).toBe(201);

      const payment = await prisma.billPayment.findFirst({
        where: { billId: res.body.id },
        include: { deposit: true },
      });
      expect(payment!.paidAt.toISOString()).toBe(billDate);
      expect(payment!.deposit!.paidAt.toISOString()).toBe(billDate);
    });

    it('unpaid bill: no payment is created', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const res = await createBill({
        buyerId,
        billDate: '2026-03-16T00:00:00.000Z',
        items: billLine(item.id),
        markPaidNow: false,
      });
      expect(res.status).toBe(201);
      expect(await prisma.billPayment.count({ where: { billId: res.body.id } })).toBe(0);
    });
  });

  describe('POST /bills/:billId/payments', () => {
    it('uses the supplied paidAt for the payment and its deposit', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const bill = await createBill({
        buyerId,
        billDate: '2026-04-01T00:00:00.000Z',
        items: billLine(item.id, 2, 10),
        markPaidNow: false,
      });
      const paidAt = '2026-04-05T00:00:00.000Z';

      const res = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 5, paidAt });
      expect(res.status).toBe(201);

      const payment = await prisma.billPayment.findUnique({
        where: { id: res.body.id },
        include: { deposit: true },
      });
      expect(payment!.paidAt.toISOString()).toBe(paidAt);
      expect(payment!.deposit!.paidAt.toISOString()).toBe(paidAt);
    });

    it('without paidAt: the payment is stamped with the current time', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const bill = await createBill({
        buyerId,
        billDate: '2026-04-02T00:00:00.000Z',
        items: billLine(item.id, 2, 10),
        markPaidNow: false,
      });

      const before = Date.now();
      const res = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 5 });
      expect(res.status).toBe(201);

      const payment = await prisma.billPayment.findUnique({ where: { id: res.body.id } });
      const diff = payment!.paidAt.getTime() - before;
      expect(diff).toBeGreaterThanOrEqual(-1000);
      expect(diff).toBeLessThan(10_000);
    });

    it('a malformed paidAt is rejected with 400 and records nothing', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const bill = await createBill({
        buyerId,
        billDate: '2026-04-03T00:00:00.000Z',
        items: billLine(item.id, 2, 10),
        markPaidNow: false,
      });
      const before = await prisma.billPayment.count({ where: { billId: bill.body.id } });

      const res = await request(app)
        .post(`/businesses/${businessId}/bills/${bill.body.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 5, paidAt: 'not-a-date' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_PAID_AT');
      expect(await prisma.billPayment.count({ where: { billId: bill.body.id } })).toBe(before);
    });
  });

  describe('POST /buyers/:buyerId/payments', () => {
    it('allocates oldest bill first; every allocation and the one deposit use the supplied paidAt', async () => {
      const buyer = await prisma.buyer.create({ data: { businessId, name: 'Allocation Buyer' } });
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const older = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId: buyer.id, billDate: '2026-01-01T00:00:00.000Z', items: billLine(item.id), markPaidNow: false });
      const newer = await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId: buyer.id, billDate: '2026-02-01T00:00:00.000Z', items: billLine(item.id), markPaidNow: false });
      const paidAt = '2026-02-10T00:00:00.000Z';

      const res = await request(app)
        .post(`/businesses/${businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 15, paidAt });
      expect(res.status).toBe(201);

      const payments = await prisma.billPayment.findMany({
        where: { billId: { in: [older.body.id, newer.body.id] } },
        include: { deposit: true },
      });
      expect(payments).toHaveLength(2);
      for (const p of payments) {
        expect(p.paidAt.toISOString()).toBe(paidAt);
        expect(p.deposit!.paidAt.toISOString()).toBe(paidAt);
      }
      const deposits = await prisma.deposit.count({ where: { buyerId: buyer.id } });
      expect(deposits).toBe(1);

      const olderPaid = payments.find((p) => p.billId === older.body.id)!;
      const newerPaid = payments.find((p) => p.billId === newer.body.id)!;
      expect(Number(olderPaid.amount)).toBe(10);
      expect(Number(newerPaid.amount)).toBe(5);
    });

    it('without paidAt: payments are stamped now, not at any bill date', async () => {
      const buyer = await prisma.buyer.create({ data: { businessId, name: 'Now Buyer' } });
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({ buyerId: buyer.id, billDate: '2020-01-01T00:00:00.000Z', items: billLine(item.id), markPaidNow: false });

      const before = Date.now();
      const res = await request(app)
        .post(`/businesses/${businessId}/buyers/${buyer.id}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 3 });
      expect(res.status).toBe(201);
      const payment = await prisma.billPayment.findUnique({ where: { id: res.body[0].id } });
      expect(payment!.paidAt.getTime()).toBeGreaterThanOrEqual(before - 1000);
    });

    it('a malformed paidAt is rejected with 400', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/buyers/${buyerId}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 1, paidAt: 'yesterday' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_PAID_AT');
    });
  });

  describe('GET /bills/:billId payment list', () => {
    it('reports each payment at its deposit time, sorted oldest first', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const bill = await createBill({
        buyerId,
        billDate: '2026-05-01T00:00:00.000Z',
        items: billLine(item.id, 3, 10),
        markPaidNow: false,
      });
      const billId = bill.body.id;

      // Two payments recorded out of chronological order.
      await request(app)
        .post(`/businesses/${businessId}/bills/${billId}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 5, paidAt: '2026-05-20T00:00:00.000Z' });
      await request(app)
        .post(`/businesses/${businessId}/bills/${billId}/payments`)
        .set('Authorization', authHeader(ownerId))
        .send({ amount: 5, paidAt: '2026-05-10T00:00:00.000Z' });

      const res = await request(app)
        .get(`/businesses/${businessId}/bills/${billId}`)
        .set('Authorization', authHeader(ownerId));
      expect(res.status).toBe(200);
      const times = res.body.payments.map((p: { paidAt: string }) => p.paidAt);
      expect(times).toEqual(['2026-05-10T00:00:00.000Z', '2026-05-20T00:00:00.000Z']);
    });

    it('a legacy payment with no deposit falls back to its own paidAt', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const bill = await createBill({
        buyerId,
        billDate: '2026-06-01T00:00:00.000Z',
        items: billLine(item.id, 2, 10),
        markPaidNow: false,
      });
      const legacyPaidAt = new Date('2026-06-02T00:00:00.000Z');
      await prisma.billPayment.create({
        data: { billId: bill.body.id, amount: 4, recordedBy: ownerId, paidAt: legacyPaidAt, depositId: null },
      });

      const res = await request(app)
        .get(`/businesses/${businessId}/bills/${bill.body.id}`)
        .set('Authorization', authHeader(ownerId));
      expect(res.body.payments).toHaveLength(1);
      expect(res.body.payments[0].paidAt).toBe(legacyPaidAt.toISOString());
    });
  });

  describe('GET /items ordering', () => {
    it('lists the most recently updated item first', async () => {
      const older = await makeTestItem(businessId, ownerId, { name: 'Order Older' });
      const newer = await makeTestItem(businessId, ownerId, { name: 'Order Newer' });
      await prisma.inventoryItem.update({
        where: { id: older.id },
        data: { updatedAt: new Date('2026-01-01T00:00:00.000Z') },
      });
      await prisma.inventoryItem.update({
        where: { id: newer.id },
        data: { updatedAt: new Date('2026-07-01T00:00:00.000Z') },
      });

      const res = await request(app)
        .get(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId));
      const names: string[] = res.body.map((i: { name: string }) => i.name);
      expect(names.indexOf('Order Newer')).toBeLessThan(names.indexOf('Order Older'));
    });
  });
});
