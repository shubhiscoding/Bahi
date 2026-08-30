-- Fix: businesses INSERT policy rejected valid inserts
-- Root cause: original policy checked auth.role() = 'authenticated', which is
-- less reliable across Supabase client versions than checking auth.uid() directly.
-- Fix: check that the inserting user IS the owner_id being set (tighter and correct).
-- Run this in Supabase SQL Editor.

DROP POLICY IF EXISTS "Authenticated users can create businesses" ON businesses;

CREATE POLICY "Users can create businesses they own"
  ON businesses FOR INSERT
  WITH CHECK (auth.uid() = owner_id);
