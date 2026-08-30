-- Fix: infinite recursion in business_members RLS policies
-- Root cause: policies on business_members queried business_members itself,
-- which re-triggers the same policy recursively (Postgres error 42P17).
-- Fix: SECURITY DEFINER helper functions bypass RLS internally, breaking the loop.
-- Run this entire script in Supabase SQL Editor.

-- ============================================================================
-- Helper functions (SECURITY DEFINER — bypass RLS on their internal query)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_business_member(_business_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM business_members
    WHERE business_id = _business_id AND user_id = _user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_business_owner(_business_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM business_members
    WHERE business_id = _business_id AND user_id = _user_id AND role = 'owner'
  );
$$;

-- ============================================================================
-- BUSINESS_MEMBERS — drop and recreate policies using the helper functions
-- ============================================================================
DROP POLICY IF EXISTS "Business members can read members" ON business_members;
DROP POLICY IF EXISTS "Business owner can remove members" ON business_members;
DROP POLICY IF EXISTS "Business owner can add members" ON business_members;

-- Read: any member of the business can see the member list
CREATE POLICY "Business members can read members"
  ON business_members FOR SELECT
  USING (public.is_business_member(business_id, auth.uid()));

-- Insert: allow (a) self-insert as owner when you own the business row,
-- (b) self-insert as member (joining via invite code — code validity is
-- already checked client-side before this insert), or (c) an existing
-- owner adding someone else.
CREATE POLICY "Users can join as owner/member; owners can add others"
  ON business_members FOR INSERT
  WITH CHECK (
    (user_id = auth.uid() AND role = 'owner' AND EXISTS (
      SELECT 1 FROM businesses b WHERE b.id = business_id AND b.owner_id = auth.uid()
    ))
    OR (user_id = auth.uid() AND role = 'member')
    OR public.is_business_owner(business_id, auth.uid())
  );

-- Delete: only the owner can remove members
CREATE POLICY "Business owner can remove members"
  ON business_members FOR DELETE
  USING (public.is_business_owner(business_id, auth.uid()));

-- ============================================================================
-- BUSINESSES — use the helper function instead of inline EXISTS
-- ============================================================================
DROP POLICY IF EXISTS "Business members can read their businesses" ON businesses;

CREATE POLICY "Business members can read their businesses"
  ON businesses FOR SELECT
  USING (public.is_business_member(id, auth.uid()));

-- ============================================================================
-- INVENTORY_ITEMS — use the helper functions instead of inline EXISTS
-- ============================================================================
DROP POLICY IF EXISTS "Business members can read inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business members can create inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business members can update inventory items" ON inventory_items;
DROP POLICY IF EXISTS "Business owner can delete inventory items" ON inventory_items;

CREATE POLICY "Business members can read inventory items"
  ON inventory_items FOR SELECT
  USING (public.is_business_member(business_id, auth.uid()));

CREATE POLICY "Business members can create inventory items"
  ON inventory_items FOR INSERT
  WITH CHECK (public.is_business_member(business_id, auth.uid()));

CREATE POLICY "Business members can update inventory items"
  ON inventory_items FOR UPDATE
  USING (public.is_business_member(business_id, auth.uid()));

CREATE POLICY "Business owner can delete inventory items"
  ON inventory_items FOR DELETE
  USING (public.is_business_owner(business_id, auth.uid()));
