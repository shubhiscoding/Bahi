-- Cleanup: drop all RLS policies, helper functions, and Realtime
-- publications made dead by the Phase 4 backend migration.
--
-- None of this is functionally necessary — the Node/Express backend
-- connects directly to Postgres via Prisma, which bypasses PostgREST/RLS
-- entirely regardless of whether these policies exist. This migration is
-- purely to avoid leaving misleading dead policies in the Supabase
-- dashboard for anyone (including future-us) who looks at it later and
-- assumes they're still doing something.

-- ============================================================================
-- Drop all policies
-- ============================================================================
DROP POLICY IF EXISTS "Users can read their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;

DROP POLICY IF EXISTS "Business members can read their businesses" ON businesses;
DROP POLICY IF EXISTS "Business owner can delete their business" ON businesses;
DROP POLICY IF EXISTS "Users can create businesses they own" ON businesses;

DROP POLICY IF EXISTS "Business members can read members" ON business_members;
DROP POLICY IF EXISTS "Business owner can remove members" ON business_members;
DROP POLICY IF EXISTS "Users can join as owner/member; owners can add others" ON business_members;

DROP POLICY IF EXISTS "Business members can read inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business members can create inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business members can update inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business owner can delete inventory items" ON inventory_items;

-- ============================================================================
-- RLS stays ENABLED with zero policies (= default-deny for anyone hitting
-- Supabase's PostgREST API directly with the anon key, which is embedded
-- in the Flutter APK and trivially extractable). This has NO effect on
-- the backend: Prisma's direct Postgres connection uses a role that
-- bypasses RLS regardless of enabled/disabled state. Disabling RLS here
-- instead would leave every table fully open via the anon key — a real
-- regression, not just dead-code cleanup — so it's deliberately left on.
-- ============================================================================

-- ============================================================================
-- Drop the SECURITY DEFINER helper functions (only existed to work
-- around RLS self-recursion — no longer called by anything)
-- ============================================================================
DROP FUNCTION IF EXISTS public.is_business_member(UUID, UUID);
DROP FUNCTION IF EXISTS public.is_business_owner(UUID, UUID);

-- ============================================================================
-- Remove from the Supabase Realtime publication — nothing subscribes via
-- Supabase Realtime anymore (replaced by the backend's own Socket.IO)
-- ============================================================================
ALTER PUBLICATION supabase_realtime DROP TABLE inventory_items;
ALTER PUBLICATION supabase_realtime DROP TABLE business_members;
