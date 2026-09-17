-- ⚠️⚠️⚠️ ANCIEN SCRIPT MANUEL — NE JAMAIS REJOUER, NI EN ENTIER NI PAR MORCEAUX ⚠️⚠️⚠️
-- Ce script réinstalle la règle anon_read_settings (USING true) : les réglages du coach lisibles par tous, dont les URL de webhooks.
-- Ces accès ont été fermés en production. L'état de référence des règles RLS est tracé dans :
--   supabase/migrations/20260917120000_rls_etat_reel_corrections_manuelles.sql
-- Pour réparer ou modifier quelque chose : écrire une nouvelle migration ciblée, jamais recoller ce fichier.
-- Conservé pour l'historique uniquement (en-tête ajouté le 17/09/2026).

-- Allow anonymous users (clients via token) to read settings (partner banners, gamif levels)
-- Run this in Supabase SQL Editor
CREATE POLICY "anon_read_settings" ON public.settings
  FOR SELECT TO anon
  USING (true);
