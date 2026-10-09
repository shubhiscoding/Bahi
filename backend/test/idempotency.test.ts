import { describe, it, expect, beforeAll, beforeEach, vi } from 'vitest';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { prisma } from '../src/prisma';
import { parseIdempotencyKey } from '../src/utils/idempotency';

// Socket broadcasts are part of the contract here: a replayed write must not
// re-announce itself to other devices. Spy on emitToBusiness to assert that.
const emitSpy = vi.fn();
vi.mock('../src/sockets', () => ({ emitToBusiness: (...args: unknown[]) => emitSpy(...args) }));

const { app, authHeader, makeTestBusiness, makeTestItem, makeTestMember } = await import('./helpers');

describe('parseIdempotencyKey', () => {
  it('returns undefined when the header is absent (legacy clients)', () => {
    expect(parseIdempotencyKey(undefined)).toBeUndefined();
  });

  it('accepts a UUID and other URL-safe keys', () => {
    const uuid = randomUUID();
    expect(parseIdempotencyKey(uuid)).toBe(uuid);
    expect(parseIdempotencyKey('abc_DEF-123')).toBe('abc_DEF-123');
  });

  it('accepts a key of exactly 128 characters', () => {
    const key = 'a'.repeat(128);
    expect(parseIdempotencyKey(key)).toBe(key);
  });

  it('rejects an empty string, a 129-char key, and characters outside [A-Za-z0-9_-]', () => {
    expect(parseIdempotencyKey('')).toBeNull();
    expect(parseIdempotencyKey('a'.repeat(129))).toBeNull();
    expect(parseIdempotencyKey('has space')).toBeNull();
    expect(parseIdempotencyKey('semi;colon')).toBeNull();
    expect(parseIdempotencyKey('new\nline')).toBeNull();
  });
});

describe('idempotent writes (Idempotency-Key)', () => {
  let businessId: string;
  let ownerId: string;
  let buyerId: string;

  beforeAll(async () => {
    ({ businessId, ownerId } = await makeTestBusiness());
    const buyer = await prisma.buyer.create({ data: { businessId, name: 'Idem Buyer' } });
    buyerId = buyer.id;
  });

  beforeEach(() => {
    emitSpy.mockClear();
  });

  const billBody = (itemId: string, quantity = 3, markPaidNow = false) => ({
    buyerId,
    items: [{ itemId, quantity, price: 10 }],
    markPaidNow,
  });

  const postBill = (key: string | undefined, body: object, bizId = businessId, actor = ownerId) => {
    const req = request(app)
      .post(`/businesses/${bizId}/bills`)
      .set('Authorization', authHeader(actor));
    if (key !== undefined) req.set('Idempotency-Key', key);
    return req.send(body);
  };

  const postItem = (key: string | undefined, body: object) => {
    const req = request(app)
      .post(`/businesses/${businessId}/items`)
      .set('Authorization', authHeader(ownerId));
    if (key !== undefined) req.set('Idempotency-Key', key);
    return req.send(body);
  };

  const addStock = (key: string | undefined, itemId: string, quantity: number) => {
    const req = request(app)
      .post(`/businesses/${businessId}/items/${itemId}/add-stock`)
      .set('Authorization', authHeader(ownerId));
    if (key !== undefined) req.set('Idempotency-Key', key);
    return req.send({ quantity });
  };

  describe('POST /bills', () => {
    it('same key twice: second call returns the first bill and writes nothing new', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const key = randomUUID();

      const first = await postBill(key, billBody(item.id, 3));
      const second = await postBill(key, billBody(item.id, 3));

      expect(first.status).toBe(201);
      expect(second.status).toBe(201);
      expect(second.body.id).toBe(first.body.id);
      expect(second.body).toEqual(first.body);

      expect(await prisma.bill.count({ where: { businessId, buyerId } })).toBeGreaterThan(0);
      const billsWithKey = await prisma.bill.count({ where: { id: first.body.id } });
      expect(billsWithKey).toBe(1);

      // Stock decremented exactly once (100 - 3), not twice.
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(97);
    });

    it('replay does not re-broadcast bill:created or item:updated', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 50 });
      const key = randomUUID();

      await postBill(key, billBody(item.id, 2));
      const callsAfterFirst = emitSpy.mock.calls.map((c) => c[1]);
      expect(callsAfterFirst).toContain('bill:created');

      emitSpy.mockClear();
      await postBill(key, billBody(item.id, 2));
      expect(emitSpy).not.toHaveBeenCalled();
    });

    it('concurrent identical requests (retry races a slow original) write exactly once', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const key = randomUUID();

      const responses = await Promise.all([
        postBill(key, billBody(item.id, 4)),
        postBill(key, billBody(item.id, 4)),
        postBill(key, billBody(item.id, 4)),
      ]);

      const statuses = responses.map((r) => r.status);
      expect(statuses.every((s) => s === 201)).toBe(true);
      const ids = new Set(responses.map((r) => r.body.id));
      expect(ids.size).toBe(1);

      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(96); // 100 - 4, once
      const saleLogs = await prisma.inventoryEditLog.count({
        where: { itemId: item.id, source: 'sale' },
      });
      expect(saleLogs).toBe(1);
    });

    it('different keys create different bills (each a real sale)', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });

      const a = await postBill(randomUUID(), billBody(item.id, 1));
      const b = await postBill(randomUUID(), billBody(item.id, 1));

      expect(a.body.id).not.toBe(b.body.id);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(98);
    });

    it('no header (older app build): every call is a new bill, as before', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });

      const a = await postBill(undefined, billBody(item.id, 1));
      const b = await postBill(undefined, billBody(item.id, 1));

      expect(a.body.id).not.toBe(b.body.id);
    });

    it('replay of a paid-now bill does not duplicate its deposit or payment', async () => {
      // Fresh buyer so the deposit count below is exact, not shared with other tests.
      const buyer = await prisma.buyer.create({ data: { businessId, name: 'Paid Replay Buyer' } });
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const key = randomUUID();
      const body = { buyerId: buyer.id, items: [{ itemId: item.id, quantity: 2, price: 10 }], markPaidNow: true };
      const send = () =>
        request(app).post(`/businesses/${businessId}/bills`).set('Authorization', authHeader(ownerId)).set('Idempotency-Key', key).send(body);

      const first = await send();
      await send();
      await send();

      const payments = await prisma.billPayment.findMany({ where: { billId: first.body.id } });
      expect(payments).toHaveLength(1);
      expect(await prisma.deposit.count({ where: { buyerId: buyer.id } })).toBe(1);
    });

    it('same key in a different business is independent', async () => {
      const other = await makeTestBusiness();
      const otherBuyer = await prisma.buyer.create({
        data: { businessId: other.businessId, name: 'Other Buyer' },
      });
      const otherItem = await makeTestItem(other.businessId, other.ownerId, { quantity: 10 });
      const item = await makeTestItem(businessId, ownerId, { quantity: 10 });
      const key = randomUUID();

      const mine = await postBill(key, billBody(item.id, 1));
      const theirs = await request(app)
        .post(`/businesses/${other.businessId}/bills`)
        .set('Authorization', authHeader(other.ownerId))
        .set('Idempotency-Key', key)
        .send({ buyerId: otherBuyer.id, items: [{ itemId: otherItem.id, quantity: 1, price: 5 }], markPaidNow: false });

      expect(theirs.status).toBe(201);
      expect(theirs.body.id).not.toBe(mine.body.id);
    });

    it('a failed (400) request stores no key, so the same key can be retried after fixing the input', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const key = randomUUID();

      const bad = await postBill(key, { buyerId, items: [{ itemId: item.id, quantity: 0, price: 10 }], markPaidNow: false });
      expect(bad.status).toBe(400);
      expect(bad.body.error).toBe('INVALID_QUANTITY');

      const good = await postBill(key, billBody(item.id, 5));
      expect(good.status).toBe(201);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(95);
    });

    it('rejects a malformed Idempotency-Key with 400 and writes nothing', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const before = await prisma.bill.count({ where: { businessId } });

      const res = await postBill('bad key with spaces', billBody(item.id, 1));
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_IDEMPOTENCY_KEY');

      expect(await prisma.bill.count({ where: { businessId } })).toBe(before);
    });

    it('a member (not just owner) can use the key too; replay still returns the same bill', async () => {
      const memberId = await makeTestMember(businessId, 'member');
      const item = await makeTestItem(businessId, ownerId, { quantity: 100 });
      const key = randomUUID();

      const send = () =>
        request(app)
          .post(`/businesses/${businessId}/bills`)
          .set('Authorization', authHeader(memberId))
          .set('Idempotency-Key', key)
          .send(billBody(item.id, 1));

      const a = await send();
      const b = await send();
      expect(a.status).toBe(201);
      expect(b.body.id).toBe(a.body.id);
    });
  });

  describe('POST /items (create)', () => {
    it('same key twice creates one item, not a duplicate', async () => {
      const key = randomUUID();
      const body = { name: 'Idem Rice', price: 40, quantity: 10, unit: 'kg' };

      const first = await postItem(key, body);
      const second = await postItem(key, body);

      expect(first.status).toBe(201);
      expect(second.status).toBe(201);
      expect(second.body.id).toBe(first.body.id);
      const count = await prisma.inventoryItem.count({ where: { businessId, name: 'Idem Rice' } });
      expect(count).toBe(1);
    });

    it('concurrent identical create requests produce exactly one item', async () => {
      const key = randomUUID();
      const body = { name: 'Race Sugar', price: 45, quantity: 5, unit: 'kg' };

      const responses = await Promise.all([postItem(key, body), postItem(key, body)]);
      expect(new Set(responses.map((r) => r.body.id)).size).toBe(1);
      const count = await prisma.inventoryItem.count({ where: { businessId, name: 'Race Sugar' } });
      expect(count).toBe(1);
    });

    it('replay does not re-broadcast item:created', async () => {
      const key = randomUUID();
      await postItem(key, { name: 'Broadcast Once', price: 1, quantity: 1, unit: 'kg' });
      emitSpy.mockClear();
      await postItem(key, { name: 'Broadcast Once', price: 1, quantity: 1, unit: 'kg' });
      expect(emitSpy).not.toHaveBeenCalled();
    });

    it('no header: two creates make two items, as before', async () => {
      const body = { name: 'Legacy Dal', price: 90, quantity: 1, unit: 'kg' };
      const a = await postItem(undefined, body);
      const b = await postItem(undefined, body);
      expect(a.body.id).not.toBe(b.body.id);
    });
  });

  describe('POST /items/:id/add-stock', () => {
    it('same key twice adds the quantity once, not twice', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 10 });
      const key = randomUUID();

      const first = await addStock(key, item.id, 5);
      const second = await addStock(key, item.id, 5);

      expect(first.status).toBe(200);
      expect(second.status).toBe(200);
      expect(second.body.quantity).toBe(15);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(15);
      const restocks = await prisma.inventoryEditLog.count({
        where: { itemId: item.id, source: 'restock' },
      });
      expect(restocks).toBe(1);
    });

    it('concurrent identical add-stock requests increment exactly once', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 0 });
      const key = randomUUID();

      await Promise.all([addStock(key, item.id, 7), addStock(key, item.id, 7), addStock(key, item.id, 7)]);

      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(7);
    });

    it('replay does not re-broadcast item:updated', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 0 });
      const key = randomUUID();
      await addStock(key, item.id, 2);
      emitSpy.mockClear();
      await addStock(key, item.id, 2);
      expect(emitSpy).not.toHaveBeenCalled();
    });

    it('different keys each add stock (two real restocks)', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 0 });
      await addStock(randomUUID(), item.id, 3);
      await addStock(randomUUID(), item.id, 3);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(6);
    });

    it('no header: each call increments, as before', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 0 });
      await addStock(undefined, item.id, 4);
      await addStock(undefined, item.id, 4);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(8);
    });

    it('a failed (400) add-stock stores no key, so a corrected retry with the same key still applies', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 1 });
      const key = randomUUID();

      const bad = await addStock(key, item.id, 0);
      expect(bad.status).toBe(400);

      const good = await addStock(key, item.id, 3);
      expect(good.status).toBe(200);
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(4);
    });

    it('rejects a malformed Idempotency-Key with 400 and changes no stock', async () => {
      const item = await makeTestItem(businessId, ownerId, { quantity: 9 });
      const res = await addStock('bad/key', item.id, 1);
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_IDEMPOTENCY_KEY');
      const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
      expect(refreshed!.quantity).toBe(9);
    });
  });

  it('a key is scoped to its endpoint: the same key on add-stock and bill create do not collide', async () => {
    const item = await makeTestItem(businessId, ownerId, { quantity: 20 });
    const key = randomUUID();

    const stock = await addStock(key, item.id, 5);
    const bill = await postBill(key, billBody(item.id, 2));

    expect(stock.status).toBe(200);
    expect(bill.status).toBe(201);
    const refreshed = await prisma.inventoryItem.findUnique({ where: { id: item.id } });
    expect(refreshed!.quantity).toBe(23); // 20 + 5 - 2
  });
});
