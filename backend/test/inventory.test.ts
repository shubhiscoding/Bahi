import { randomUUID } from 'crypto';
import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { app, authHeader, makeTestBusiness, makeTestMember, makeTestItem } from './helpers';
import { prisma } from '../src/prisma';

describe('inventory items', () => {
  let businessId: string;
  let ownerId: string;

  beforeAll(async () => {
    ({ businessId, ownerId } = await makeTestBusiness());
  });

  describe('POST /businesses/:id/items — validation', () => {
    it('rejects negative price', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'आटा', price: -5, quantity: 10, unit: 'kg' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_PRICE');
    });

    it('rejects negative quantity', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'आटा', price: 10, quantity: -1, unit: 'kg' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('rejects non-integer quantity', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'आटा', price: 10, quantity: 2.5, unit: 'kg' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('rejects empty name', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: '  ', price: 10, quantity: 1, unit: 'kg' });
      expect(res.status).toBe(400);
    });

    it('allows price of exactly 0', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'फ्री सैंपल', price: 0, quantity: 1, unit: 'piece' });
      expect(res.status).toBe(201);
    });

    it('creates a valid item and seeds price history', async () => {
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'चीनी', price: 40, quantity: 20, unit: 'kg' });
      expect(res.status).toBe(201);
      const itemId = res.body.id;

      const history = await request(app)
        .get(`/businesses/${businessId}/items/${itemId}/price-history`)
        .set('Authorization', authHeader(ownerId));
      expect(history.body).toHaveLength(1);
      expect(Number(history.body[0].price)).toBe(40);
    });

    it('a non-member gets 403', async () => {
      const outsiderId = randomUUID(); // valid UUID, but not a member of businessId
      const res = await request(app)
        .post(`/businesses/${businessId}/items`)
        .set('Authorization', authHeader(outsiderId))
        .send({ name: 'x', price: 1, quantity: 1, unit: 'piece' });
      expect(res.status).toBe(403);
    });
  });

  describe('PUT /businesses/:id/items/:itemId — edit log + price history', () => {
    it('rejects negative price on update', async () => {
      const item = await makeTestItem(businessId, ownerId, { price: 10 });
      const res = await request(app)
        .put(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ price: -1, quantity: item.quantity, unit: item.unit });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_PRICE');
    });

    it('a no-op save (nothing changed) writes zero edit-log rows', async () => {
      const item = await makeTestItem(businessId, ownerId);
      await request(app)
        .put(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ price: Number(item.price), quantity: item.quantity, unit: item.unit });

      const log = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/edit-log`)
        .set('Authorization', authHeader(ownerId));
      expect(log.body).toHaveLength(0);
    });

    it('changing price writes one edit-log row and one price-history point', async () => {
      const item = await makeTestItem(businessId, ownerId, { name: 'नमक', price: 20 });
      await request(app)
        .put(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ price: 25, quantity: item.quantity, unit: item.unit });

      const log = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/edit-log`)
        .set('Authorization', authHeader(ownerId));
      expect(log.body).toHaveLength(1);
      expect(log.body[0].source).toBe('edit');
      expect(log.body[0].changes.price).toBeTruthy();
      expect(log.body[0].changes.name).toBeUndefined();

      const history = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/price-history`)
        .set('Authorization', authHeader(ownerId));
      expect(history.body).toHaveLength(2); // seed + this change
    });

    // Name is set once at creation and intentionally not editable
    // afterward (confirmed decision) — this asserts the removal actually
    // holds at the API level, not just that the UI hides the field.
    it('ignores a name sent on update — name never changes via PUT', async () => {
      const item = await makeTestItem(businessId, ownerId, { name: 'नमक' });
      const res = await request(app)
        .put(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ name: 'सेंधा नमक', price: Number(item.price), quantity: item.quantity, unit: item.unit });

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('नमक');

      const log = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/edit-log`)
        .set('Authorization', authHeader(ownerId));
      expect(log.body).toHaveLength(0); // nothing actually changed
    });

    it('changing only quantity does NOT write a price-history row', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 5 });
      await request(app)
        .put(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ price: Number(item.price), quantity: 50, unit: item.unit });

      const history = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/price-history`)
        .set('Authorization', authHeader(ownerId));
      expect(history.body).toHaveLength(1); // just the seed
    });

    it('rejects editing an item that belongs to a different business (404, not leaked)', async () => {
      const other = await makeTestBusiness();
      const otherItem = await makeTestItem(other.businessId, other.ownerId);

      const res = await request(app)
        .put(`/businesses/${businessId}/items/${otherItem.id}`)
        .set('Authorization', authHeader(ownerId))
        .send({ price: 1, quantity: 1, unit: 'piece' });
      expect(res.status).toBe(404);
    });
  });

  describe('POST /businesses/:id/items/:itemId/add-stock', () => {
    it('rejects zero', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const res = await request(app)
        .post(`/businesses/${businessId}/items/${item.id}/add-stock`)
        .set('Authorization', authHeader(ownerId))
        .send({ quantity: 0 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('rejects negative', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const res = await request(app)
        .post(`/businesses/${businessId}/items/${item.id}/add-stock`)
        .set('Authorization', authHeader(ownerId))
        .send({ quantity: -10 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('rejects non-integer', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const res = await request(app)
        .post(`/businesses/${businessId}/items/${item.id}/add-stock`)
        .set('Authorization', authHeader(ownerId))
        .send({ quantity: 1.5 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_QUANTITY');
    });

    it('increments quantity, logs source=restock, does not touch price history', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 10, price: 15 });
      const res = await request(app)
        .post(`/businesses/${businessId}/items/${item.id}/add-stock`)
        .set('Authorization', authHeader(ownerId))
        .send({ quantity: 5 });
      expect(res.status).toBe(200);
      expect(res.body.quantity).toBe(15);

      const log = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/edit-log`)
        .set('Authorization', authHeader(ownerId));
      expect(log.body).toHaveLength(1);
      expect(log.body[0].source).toBe('restock');
      expect(log.body[0].changes.quantity).toEqual({ from: 10, to: 15 });

      const history = await request(app)
        .get(`/businesses/${businessId}/items/${item.id}/price-history`)
        .set('Authorization', authHeader(ownerId));
      expect(history.body).toHaveLength(1); // just the seed — price never touched
    });
  });

  describe('DELETE /businesses/:id/items/:itemId — billed items are protected', () => {
    it('a member (not owner) gets 403', async () => {
      const item = await makeTestItem(businessId, ownerId);
      const memberId = await makeTestMember(businessId);
      const res = await request(app)
        .delete(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(memberId));
      expect(res.status).toBe(403);
    });

    it('deleting an item that has been billed at least once fails instead of orphaning history', async () => {
      const buyer = await prisma.buyer.create({ data: { businessId, name: 'Delete Test Buyer' } });
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      await request(app)
        .post(`/businesses/${businessId}/bills`)
        .set('Authorization', authHeader(ownerId))
        .send({
          buyerId: buyer.id,
          items: [{ itemId: item.id, quantity: 1, price: 10 }],
          markPaidNow: true,
        });

      const res = await request(app)
        .delete(`/businesses/${businessId}/items/${item.id}`)
        .set('Authorization', authHeader(ownerId));
      // Restrict FK — Prisma throws P2003, caught by the generic error
      // handler as a 500. Asserting it's rejected (not 204), not the
      // exact status code, since that's an implementation detail.
      expect(res.status).not.toBe(204);
    });
  });
});
