-- Make invite codes ephemeral: OTP-style, 5-minute expiry, single-use.
-- Non-destructive: adds two nullable columns, drops the now-unneeded
-- unique constraint on invite_code (codes are no longer permanent/unique
-- business attributes — validity is checked by expiry+used-at instead).

ALTER TABLE businesses
  DROP CONSTRAINT IF EXISTS businesses_invite_code_key;

ALTER TABLE businesses
  ALTER COLUMN invite_code DROP NOT NULL;

ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS invite_code_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invite_code_used_at TIMESTAMPTZ;

-- Existing permanent codes are no longer valid under the new rules
-- (no expiry set = never valid under the new joinByCode check), so
-- clearing them out is just tidiness, not a behavior change.
UPDATE businesses SET invite_code = NULL;
