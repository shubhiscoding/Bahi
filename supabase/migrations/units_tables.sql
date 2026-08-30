-- Per-business unit list, replacing the hardcoded 8-item unit list in the
-- Flutter app. `units` is a global catalog (deduplicated by name);
-- `business_units` links a business to the units it has adopted — every
-- new business gets 3 seed units linked at creation time (done in code,
-- not here; this migration only creates the tables + the 3 canonical
-- catalog rows so they exist ready to be linked).

CREATE TABLE IF NOT EXISTS units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS business_units (
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, unit_id)
);

CREATE INDEX IF NOT EXISTS idx_business_units_business_id ON business_units(business_id);

-- Same default-deny posture as every other table (RLS enabled with zero
-- policies blocks direct PostgREST/anon-key access; the backend's Prisma
-- connection bypasses RLS regardless via rolbypassrls).
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_units ENABLE ROW LEVEL SECURITY;

-- Seed the 3 canonical unit names used across the app (matches existing
-- Strings.unitBox/unitKg/unitLitre constants — reusing existing copy,
-- not inventing new labels).
INSERT INTO units (name) VALUES ('डिब्बा'), ('किग्रा'), ('लीटर')
ON CONFLICT (name) DO NOTHING;
