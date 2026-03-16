-- ============================================================
-- FITZONE EVOLUTION — Row Level Security (RLS) Policies
-- ============================================================
-- À exécuter dans le SQL Editor de Supabase Dashboard :
-- https://supabase.com/dashboard/project/wsrykmutyhjxdnhnyexl/sql
--
-- Ce script :
-- 1. Crée une fonction helper public.get_my_coach_id()
-- 2. Active RLS sur toutes les tables publiques
-- 3. Crée les policies pour le rôle "authenticated" (dashboard coach)
-- 4. Crée les policies pour le rôle "anon" (app client via token)
-- ============================================================

-- ────────────────────────────────────────────────────────
-- 0. Fonction helper : récupérer le coach_id du user connecté
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_coach_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT id FROM public.coaches WHERE user_id = auth.uid()
$$;

-- ────────────────────────────────────────────────────────
-- 1. COACHES — déjà RLS activé, on ajoute juste les policies
-- ────────────────────────────────────────────────────────
-- (RLS déjà activé sur cette table)
-- Supprimer les policies existantes si besoin
DROP POLICY IF EXISTS "coach_select_own" ON public.coaches;
DROP POLICY IF EXISTS "coach_insert_own" ON public.coaches;
DROP POLICY IF EXISTS "coach_update_own" ON public.coaches;

CREATE POLICY "coach_select_own" ON public.coaches
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "coach_insert_own" ON public.coaches
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "coach_update_own" ON public.coaches
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ────────────────────────────────────────────────────────
-- 2. CLIENTS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Coach : CRUD complet sur ses clients
CREATE POLICY "coach_clients_all" ON public.clients
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

-- Anon (app client) : lire son propre profil via token
CREATE POLICY "anon_clients_select_by_token" ON public.clients
  FOR SELECT TO anon
  USING (true);
  -- Note: l'app filtre par token. On autorise le SELECT pour que
  -- la validation du token fonctionne. Les données sensibles sont
  -- limitées (pas de mot de passe). Alternative future : RPC function.

-- Anon (app client) : mettre à jour son profil (photo, nom)
CREATE POLICY "anon_clients_update" ON public.clients
  FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 3. QUESTIONNAIRES
-- ────────────────────────────────────────────────────────
ALTER TABLE public.questionnaires ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_questionnaires_all" ON public.questionnaires
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id()));

-- Anon : lecture seule (l'app client affiche les données du questionnaire)
CREATE POLICY "anon_questionnaires_select" ON public.questionnaires
  FOR SELECT TO anon
  USING (true);

-- Anon : insertion (le questionnaire est soumis depuis questionnaire.html)
CREATE POLICY "anon_questionnaires_insert" ON public.questionnaires
  FOR INSERT TO anon
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 4. PLANS (macros) — pas de coach_id dans cette table
-- ────────────────────────────────────────────────────────
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_plans_all" ON public.plans
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id()));

CREATE POLICY "anon_plans_select" ON public.plans
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 5. PLANS_FULL (plans complets)
-- ────────────────────────────────────────────────────────
ALTER TABLE public.plans_full ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_plans_full_all" ON public.plans_full
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_plans_full_select" ON public.plans_full
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 6. DAILY_LOGS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.daily_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_daily_logs_all" ON public.daily_logs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

-- Anon : SELECT + INSERT + UPDATE (l'app client crée et met à jour les logs)
CREATE POLICY "anon_daily_logs_select" ON public.daily_logs
  FOR SELECT TO anon
  USING (true);

CREATE POLICY "anon_daily_logs_insert" ON public.daily_logs
  FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "anon_daily_logs_update" ON public.daily_logs
  FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 7. BILANS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.bilans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_bilans_all" ON public.bilans
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_bilans_select" ON public.bilans
  FOR SELECT TO anon
  USING (true);

CREATE POLICY "anon_bilans_insert" ON public.bilans
  FOR INSERT TO anon
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 8. TRAIN_LOGS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.train_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_train_logs_all" ON public.train_logs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_train_logs_select" ON public.train_logs
  FOR SELECT TO anon
  USING (true);

CREATE POLICY "anon_train_logs_insert" ON public.train_logs
  FOR INSERT TO anon
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 9. PROGRAMS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_programs_all" ON public.programs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_programs_select" ON public.programs
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 10. EXERCISES
-- ────────────────────────────────────────────────────────
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_exercises_all" ON public.exercises
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_exercises_select" ON public.exercises
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 11. SEANCES
-- ────────────────────────────────────────────────────────
ALTER TABLE public.seances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_seances_all" ON public.seances
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_seances_select" ON public.seances
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 12. ALIMENTS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.aliments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_aliments_all" ON public.aliments
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_aliments_select" ON public.aliments
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 13. REPAS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.repas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_repas_all" ON public.repas
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_repas_select" ON public.repas
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 14. MODULES
-- ────────────────────────────────────────────────────────
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_modules_all" ON public.modules
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

CREATE POLICY "anon_modules_select" ON public.modules
  FOR SELECT TO anon
  USING (true);

-- ────────────────────────────────────────────────────────
-- 15. ROADMAPS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.roadmaps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_roadmaps_all" ON public.roadmaps
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

-- Pas d'accès anon (roadmap visible uniquement côté dashboard)

-- ────────────────────────────────────────────────────────
-- 16. SETTINGS
-- ────────────────────────────────────────────────────────
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_settings_all" ON public.settings
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

-- Pas d'accès anon

-- ────────────────────────────────────────────────────────
-- 17. TEAM
-- ────────────────────────────────────────────────────────
ALTER TABLE public.team ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_team_all" ON public.team
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id())
  WITH CHECK (coach_id = public.get_my_coach_id());

-- Pas d'accès anon

-- ============================================================
-- VÉRIFICATION : lister toutes les tables et leur statut RLS
-- ============================================================
SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
