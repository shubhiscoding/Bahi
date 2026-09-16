# Agent Guidelines — Production Safety & Data Integrity

**This file applies to ALL agents (Claude sessions) working on this project.**

---

## 1. PRODUCTION DATABASE — ABSOLUTE PROTECTION

### Rule: Never touch production Supabase without explicit permission

- **Default behavior:** Work ONLY against local dev database (`bahi_dev`)
- **Prod access triggers:** Only when user explicitly requests production changes
- **Permission protocol:**
  1. User says: "I want to [change] in production" or "run this migration against prod"
  2. You MUST ask: "I need explicit confirmation before touching prod. Are you sure you want me to proceed? Reply YES to confirm."
  3. User MUST reply with exactly: "YES" (or "yes" / "Yes")
  4. ONLY THEN proceed with the change
  5. **Do NOT proceed if user says:** "yeah", "ok", "sure", "go ahead", or anything other than explicit YES

- **No exceptions.** Not for hotfixes, not for emergencies, not for "just checking". Always ask.
- **Document every prod access:** Log what changed, when, why in comments or commit messages
- **Rollback plan required:** Before any prod change, have a rollback procedure ready (migrations must be reversible)

---

## 2. DATA INTEGRITY — THE GOLDEN RULE

### Philosophy: Data is the most critical asset. No data loss, ever.

**This overrides all other considerations.**

#### 2.1 Zero Data Loss Policy
- User data (profiles, bills, inventory, payments) is **permanent**
- NEVER delete rows in production
- NEVER drop columns or tables
- NEVER truncate tables
- NEVER lose transaction history

#### 2.2 Soft Deletes Only
- **All delete operations in APIs must be soft deletes:**
  - Add `deletedAt` timestamp column (nullable, default NULL)
  - OR add `isDeleted` boolean (default false)
  - Mark as deleted, never remove from DB
  
- **Hard deletes are ONLY allowed in:**
  - Local dev/test environments
  - Temporary/ephemeral data (cache, sessions, temp uploads)
  - **Never** for user-created business data

- **When soft deletes are applied:**
  - Query filtering: always `WHERE deletedAt IS NULL` or `WHERE isDeleted = false`
  - Restore capability: expose API endpoints to undelete if needed
  - Audit trail: soft-deleted rows remain for compliance/recovery

#### 2.3 Data Audit Trail
- All mutations (create, update, delete) must be logged:
  - Who made the change (userId)
  - When (timestamp)
  - What changed (before/after values, or just the action)
  - Why (user action, system action, migration, etc.)
  
- This is non-negotiable for production.

---

## 3. SCHEMA CHANGES — BACKWARD COMPATIBILITY ONLY

### Rule: Every migration must be reversible and safe under load

#### 3.1 Adding Columns
- ✅ **Safe:** `ADD COLUMN ... DEFAULT ...` with a safe default value
- ✅ **Safe:** `ADD COLUMN ... NULLABLE` (no default needed)
- ❌ **Unsafe:** `ADD COLUMN ... NOT NULL` without a default (breaks existing rows)

#### 3.2 Removing Columns
- ❌ **NEVER** drop columns in production
- ✅ **Instead:** Mark as deprecated, hide from API, leave in DB for recovery
- Test removal in local first. If it must go in prod, give 2+ releases notice and soft-delete the data first.

#### 3.3 Changing Column Types
- ❌ **NEVER** change types (e.g., INT → STRING) without a safe migration path
- ✅ **Instead:** Create new column with new type, backfill data, deprecate old column, drop in later release

#### 3.4 Removing Tables
- ❌ **NEVER** drop tables in production
- ✅ **Instead:** Mark as deprecated, stop querying it, archive it in a backup environment first

#### 3.5 Adding Constraints
- ❌ **UNSAFE:** `NOT NULL` constraint on existing nullable column with data
- ❌ **UNSAFE:** `UNIQUE` constraint on a column with duplicates
- ❌ **UNSAFE:** `FOREIGN KEY` that references data that doesn't exist
- ✅ **Safe:** Backfill missing values first, then add constraint (verified in local)

#### 3.6 Foreign Keys & Cascades
- **`onDelete: Cascade`** is only safe for **derived/computed data** (e.g., cached counts, audit logs, indexes)
- **`onDelete: Restrict`** for **critical data** (e.g., bills referencing items) — this protects data from accidental loss
- **Document why:** Add a comment in schema explaining the choice
- **Test cascades in local:** Verify no unexpected data loss

#### 3.7 Index & Performance Changes
- ✅ Safe to add indexes without downtime
- ⚠️ Safe to remove indexes, but verify query performance first
- ❌ Never remove an index without confirming no critical queries depend on it

---

## 4. DELETION OPERATIONS — SOFT DELETE MANDATE

### Rule: All delete endpoints MUST soft-delete

#### 4.1 Delete Item
- Current behavior: Hard delete (blocks if item is billed)
- **Required change:** Soft delete instead
  - Add `deletedAt` column to `inventory_items`
  - Update schema: `model InventoryItem { ... deletedAt DateTime? }`
  - Update queries: `WHERE deletedAt IS NULL` in all reads
  - Remove FK hard constraint on bills (change to `onDelete: SetNull` or keep but filter on deletedAt)
  - **Never hard delete** even if unbilled

#### 4.2 Delete Business
- Current behavior: Hard delete with cascades
- **Required change:** Soft delete
  - Add `deletedAt` to `Business`, `Buyer`, `Bill`, `Deposit`
  - Owner can "delete" business → just marks it deletedAt
  - Business becomes invisible in app but data is retained
  - Optional: expose admin restore endpoint

#### 4.3 Delete Member / Leave Business
- Current behavior: Hard delete from `BusinessMember`
- **Required change:** Soft delete
  - Add `deletedAt` to `BusinessMember`
  - Mark member as left, don't remove the row
  - Historical record remains for audits

#### 4.4 Refund / Reverse Payment
- Current behavior: None (payments are immutable)
- **Best practice:** Never delete a `BillPayment`
  - Instead: Create an inverse `BillPayment` with negative amount
  - Preserves the ledger and audit trail
  - Always have: original payment, reversal, explanation

---

## 5. TESTING & VALIDATION — LOCAL FIRST, ALWAYS

### Rule: Every change must be tested locally before touching prod

#### 5.1 Local Testing Checklist
- [ ] Change is made on local branch
- [ ] Schema changes are applied to local DB (`bahi_dev`)
- [ ] Seed data is loaded (via `npm run seed:local`)
- [ ] Change is tested with realistic data (not just empty DB)
- [ ] Backward compatibility verified (old API clients still work)
- [ ] Edge cases tested (empty results, boundary conditions, concurrent writes)
- [ ] Performance verified (migration doesn't time out on large tables)
- [ ] Build succeeds (`flutter analyze`, `flutter build`, `npm run build`)
- [ ] Tests pass (if tests exist)

#### 5.2 Migration Testing
- **Test on local:** Apply migration, verify no errors
- **Test on realistic data:** Run against seeded DB (not just schema)
- **Test rollback:** Reverse the migration, verify data is intact
- **Test on large tables:** If targeting big tables, measure time locally
- **Document time estimate:** How long will this take on prod? (scale up from local measurement)

#### 5.3 Seed Data Requirements
- Local DB should have realistic test data (not just one row per table)
- Include edge cases: empty fields, boundary values, old data
- Seed script documents what's created (see `backend/prisma/seed.ts`)

---

## 6. PRODUCTION PRACTICES — STANDARD GUARDRAILS

### 6.1 Migrations
- ✅ Migrations are version-controlled (timestamped SQL files)
- ✅ Migrations are idempotent (safe to run twice)
- ✅ Migrations have rollback scripts (always include `DOWN` migration)
- ✅ Migrations are tested in local/staging before prod
- ❌ No raw SQL in production code (use migrations only)
- ❌ No bypassing migration system (no manual DB changes)

### 6.2 Deployments
- ✅ Migrations are deployed before app code (or vice versa, consistently)
- ✅ Rollback plan is documented before deploy
- ✅ Data backup is taken before any schema change
- ✅ One breaking change at a time (don't mix multiple incompatible changes)
- ❌ Never deploy during business hours without monitoring
- ❌ Never deploy without having a way to revert

### 6.3 Monitoring & Alerting
- ✅ Monitor query performance after schema changes
- ✅ Monitor app error logs for migration-related failures
- ✅ Monitor database size growth (watch for unexpected bloat)
- ✅ Alert on: failed migrations, data corruption, unauthorized access

### 6.4 Secrets & Access Control
- ✅ Prod DB credentials are restricted to: deploy scripts, backend, DevOps
- ✅ Never log credentials, connection strings, or sensitive env vars
- ✅ Never commit `.env` with real prod values
- ❌ Agents should never ask for prod credentials
- ❌ Agents should never suggest storing creds in code

### 6.5 Backup & Recovery
- ✅ Prod DB is backed up daily (Supabase handles this)
- ✅ Backups are tested (verify they restore successfully)
- ✅ Recovery procedures are documented
- ✅ For critical changes, a backup is taken immediately before

### 6.6 Audit & Compliance
- ✅ All data mutations are logged (who, when, what)
- ✅ Sensitive operations (delete, permissions) are audited
- ✅ Logs are retained for ≥90 days (compliance requirement)
- ✅ Soft deletes allow data recovery for compliance audits

### 6.7 Local Development Configuration
- ❌ **NEVER commit local-only config changes** (e.g. swapping backend URLs, API keys, database configs to local/dev)
- Local config changes belong in `.env`, `.env.local`, or gitignored files only
- Always verify a file is NOT gitignored before committing it
- Before committing: check that the change is prod-appropriate (would you want this deployed?)
- If you make a local config change by accident, revert immediately with `git reset --soft HEAD~1` + restore the file

---

## 7. DECISION FLOWCHART — WHEN IN DOUBT

```
User asks for change in production?
├─ NO → Work on local branch
├─ YES → Ask user explicit confirmation
    ├─ User says YES → Proceed (after verification)
    ├─ User says anything else → Wait for explicit YES
```

```
Change involves deleting data?
├─ Is it user-created business data? → SOFT DELETE
├─ Is it session/temp/cache? → Hard delete OK
├─ Is it audit log? → Keep forever
```

```
Schema change planned?
├─ Adding column? → Must have safe default
├─ Removing column? → Never in prod, deprecate first
├─ Changing type? → Create new column, backfill, deprecate old
├─ Adding constraint? → Backfill data first, verify in local
```

```
Ready to deploy?
├─ Tested locally? → Must be yes
├─ Backward compatible? → Must be yes
├─ Rollback plan? → Must exist
├─ Prod access confirmed? → Must be explicit YES
├─ Then deploy
```

---

## 8. SPECIFIC GUARDRAILS FOR THIS PROJECT

### Current Prod State (as of Sept 2026)
- **Soft deletes:** NOT YET implemented (hard deletes still in use)
- **Audit logs:** Partially implemented (InventoryEditLog exists, others TBD)
- **Data stability:** Stable (no major losses so far)
- **Backup policy:** Daily Supabase backups (user has access)

### Mandatory Soft-Delete Migration (Priority: HIGH)
- [ ] Add `deletedAt` to: `InventoryItem`, `Business`, `Buyer`, `Bill`, `Deposit`, `BusinessMember`
- [ ] Update all DELETE APIs to soft-delete
- [ ] Update all SELECT queries to filter `deletedAt IS NULL`
- [ ] Test in local with realistic data
- [ ] Deploy to prod (with rollback plan)
- [ ] This is a breaking change on queries, but not on data

### No Hard Deletes Allowed Going Forward
- Any new feature that deletes data must soft-delete
- All existing hard-delete endpoints should be migrated to soft-delete
- Exceptions require explicit override with written justification

---

## 9. AGENT RESPONSIBILITIES

### Before Any Prod Work
- [ ] I have read this file
- [ ] I understand the data is sacred
- [ ] I will not touch prod without explicit YES
- [ ] I will test locally first
- [ ] I will soft-delete, never hard-delete

### When User Asks for Prod Change
1. **Stop and ask:** "I need explicit confirmation. Are you sure you want me to proceed? Reply YES to confirm."
2. **Wait for YES:** Don't guess, don't interpret "ok" as "yes"
3. **Have a rollback plan:** Before proceeding, verify reversibility
4. **Document the change:** Commit message and/or PR should explain why

### When User Asks for Deletion
1. **Confirm it's soft-delete:** "I will mark this as deleted, keeping the data in the DB for recovery. Proceed?"
2. **If user insists on hard delete:** "This cannot be undone and violates our data policy. I cannot proceed without explicit override and a documented reason."
3. **Hard deletes are rare:** Only for temporary/cache data, never for user data

---

## 10. ESCALATION POLICY

When in doubt, ask. When there's a conflict, escalate:

- **Unclear prod access:** Ask user for explicit permission
- **Data safety conflict:** Prioritize data preservation
- **Backward compatibility doubt:** Test in local, don't guess
- **Large migration uncertainty:** Break into smaller steps, test each step
- **Compliance question:** Document and preserve data, ask for confirmation

---

## 11. REMEMBER

**User data is the business. Losing it is existential.**

Every agent working on this project must internalize that principle. 

- **Question assumptions** about data safety
- **Verify before deleting** — always soft-delete unless absolutely sure
- **Test locally first** — with real data, not empty tables
- **Ask for permission** — explicit YES, not implicit consent
- **Keep an audit trail** — who, when, what, why
- **Preserve reversibility** — every change must be undoable

This is production. Act like it.
