-- Allow anonymous users (clients via token) to read settings (partner banners, gamif levels)
-- Run this in Supabase SQL Editor
CREATE POLICY "anon_read_settings" ON public.settings
  FOR SELECT TO anon
  USING (true);
