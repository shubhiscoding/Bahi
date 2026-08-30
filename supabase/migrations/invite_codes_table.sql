-- Redesign invite codes as a proper table instead of 3 columns on
-- businesses, overwritten on every generate. Enables multiple concurrent
-- valid codes per business (e.g. one per new hire), each independently
-- 5-minute, single-use — confirmed requirement, not the old "only one
-- active code at a time" model.

CREATE TABLE IF NOT EXISTS invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  used_by UUID REFERENCES profiles(id),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_invite_codes_business_id ON invite_codes(business_id);

-- Same default-deny posture as the other tables (see drop_dead_rls.sql):
-- RLS enabled with zero policies blocks direct PostgREST/anon-key access;
-- the backend's Prisma connection bypasses RLS regardless (rolbypassrls).
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Drop the old single-code-per-business columns — superseded by this table.
ALTER TABLE businesses
  DROP COLUMN IF EXISTS invite_code,
  DROP COLUMN IF EXISTS invite_code_expires_at,
  DROP COLUMN IF EXISTS invite_code_used_at;

DROP INDEX IF EXISTS idx_businesses_invite_code;
