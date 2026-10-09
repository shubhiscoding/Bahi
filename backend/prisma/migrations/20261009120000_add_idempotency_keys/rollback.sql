-- ROLLBACK (manual, not run by prisma migrate).
-- Safe: the table holds only replay bookkeeping; no business data depends on it.
DROP TABLE IF EXISTS "idempotency_keys";
