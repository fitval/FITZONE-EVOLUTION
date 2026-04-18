-- Add partner column to settings table for partner banner on client home page
-- Run this in Supabase SQL Editor
ALTER TABLE settings ADD COLUMN IF NOT EXISTS partner jsonb DEFAULT NULL;
