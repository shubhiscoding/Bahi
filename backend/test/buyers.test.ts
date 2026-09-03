import { randomUUID } from 'crypto';
import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { app, authHeader, makeTestBusiness } from './helpers';

describe('buyers', () => {
  let businessId: string;
  let ownerId: string;

  beforeAll(async () => {
    ({ businessId, ownerId } = await makeTestBusiness());
  });

  it('rejects empty name', async () => {
    const res = await request(app)
      .post(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(ownerId))
      .send({ name: '   ' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('EMPTY_NAME');
  });

  it('creates a buyer', async () => {
    const res = await request(app)
      .post(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(ownerId))
      .send({ name: 'रमेश' });
    expect(res.status).toBe(201);
    expect(res.body.name).toBe('रमेश');
  });

  it('rejects an exact duplicate name within the same business', async () => {
    // 'रमेश' was already created in the previous test, same businessId.
    const res = await request(app)
      .post(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(ownerId))
      .send({ name: 'रमेश' });
    expect(res.status).toBe(409);
    expect(res.body.error).toBe('DUPLICATE_NAME');
  });

  it('rejects a case-insensitive duplicate (ASCII) name within the same business', async () => {
    const first = await request(app)
      .post(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(ownerId))
      .send({ name: 'Suresh Traders' });
    expect(first.status).toBe(201);

    const dup = await request(app)
      .post(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(ownerId))
      .send({ name: 'suresh traders' });
    expect(dup.status).toBe(409);
    expect(dup.body.error).toBe('DUPLICATE_NAME');
  });

  it('the same buyer name is allowed in a different business', async () => {
    const other = await makeTestBusiness();
    const res = await request(app)
      .post(`/businesses/${other.businessId}/buyers`)
      .set('Authorization', authHeader(other.ownerId))
      .send({ name: 'रमेश' });
    expect(res.status).toBe(201);
  });

  it('a non-member gets 403', async () => {
    const res = await request(app)
      .get(`/businesses/${businessId}/buyers`)
      .set('Authorization', authHeader(randomUUID())); // valid UUID, but not a member
    expect(res.status).toBe(403);
  });
});
