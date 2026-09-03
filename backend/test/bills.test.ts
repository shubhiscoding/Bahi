import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { app, authHeader, makeTestBusiness, makeTestItem } from './helpers';
import { prisma } from '../src/prisma';

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
});
