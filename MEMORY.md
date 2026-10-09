# Decision log

## Retry on timeout for bill create, item create, add-stock (2026-10-09)

**Decided:** The app retries these three writes up to 3 attempts total, with 1s then 2s between tries. Only network timeouts and connection errors are retried. The saving loader stays up for the whole run. After the last failure, the user sees "Internet is slow, please try again later".

**Why:** Slow internet was failing saves with a raw error and no recovery.

**Required safety (the non-obvious part):** A timed-out POST may already have committed on the server. A plain retry would then create a duplicate bill, a duplicate item, or add stock twice. Each save therefore sends an `Idempotency-Key` header. The same key is reused across that save's attempts. The backend stores the first successful response in the same transaction as the write (`IdempotencyKey` table, unique on business+scope+key), and replays it on a retry.

**Rejected:**
- Retrying without idempotency keys: double-writes on any slow-but-successful request.
- Client-side dedupe only: cannot cover a request the server already committed.
- Retrying HTTP 5xx: the server answered, so the outcome is unknown without a key. Left out to keep the change narrow.
- Retrying `updateItem` and payments: not in scope. They are idempotent-ish but untested for this, so they are unchanged.

**Deploy order:** Backend first (migration `20261009120000_add_idempotency_keys`, then code), then the app. An old backend ignores the header, so retries are not protected until the backend is deployed. Rollback SQL is in `backend/prisma/migrations/20261009120000_add_idempotency_keys/rollback.sql`.

**Open:**
- Manual re-tap after the "slow internet" message starts a new key, so a save that actually committed earlier could be duplicated. Accepted for now.
- Partial-payment step after bill create is still not retried.
