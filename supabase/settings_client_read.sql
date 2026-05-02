-- ============================================================
-- FITZONE EVOLUTION — Lecture des settings côté CLIENT
-- ============================================================
-- 🚨 EXÉCUTER CETTE MIGRATION DANS LE SQL EDITOR DE SUPABASE
--
-- Problème : la policy RLS v2 "auth_settings_coach" n'autorise QUE
-- les coachs (et admins) à lire la table `settings`. Les clients
-- authentifiés (via `clients.user_id`) sont bloqués → q_bilan,
-- q_daily, q_integration, partner, gamif_levels ne remontent pas
-- côté app client.
--
-- Cette migration ajoute :
-- 1. Une policy SELECT pour les clients authentifiés (settings du
--    coach auquel ils sont rattachés).
-- 2. Recrée la policy anon (pour les clients en mode token legacy)
--    au cas où elle aurait été supprimée par rls_v2_policies.sql.
-- ============================================================

-- 1) Authenticated clients : peuvent lire les settings de leur coach
DROP POLICY IF EXISTS "auth_settings_client_read" ON public.settings;
CREATE POLICY "auth_settings_client_read" ON public.settings
  FOR SELECT TO authenticated
  USING (
    coach_id IN (
      SELECT coach_id FROM public.clients
      WHERE user_id = auth.uid() AND user_id IS NOT NULL
    )
  );

-- 2) Anon (token legacy) : lecture libre des settings
DROP POLICY IF EXISTS "anon_read_settings" ON public.settings;
CREATE POLICY "anon_read_settings" ON public.settings
  FOR SELECT TO anon
  USING (true);

-- Vérification :
-- SELECT policyname, roles FROM pg_policies
--   WHERE schemaname='public' AND tablename='settings' ORDER BY policyname;
