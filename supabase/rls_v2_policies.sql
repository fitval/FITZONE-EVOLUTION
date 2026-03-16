-- ============================================================
-- FITZONE EVOLUTION — RLS v2 : Admin + Client Auth
-- ============================================================
-- À exécuter dans le SQL Editor de Supabase Dashboard
-- Ce script remplace les policies v1 par un système 3 niveaux :
-- admin (voit tout) > coach (ses données) > client (ses données)
-- ============================================================

-- ────────────────────────────────────────────────────────
-- 0. Nouvelles colonnes
-- ────────────────────────────────────────────────────────
ALTER TABLE public.coaches ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'coach';
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_clients_user_id ON public.clients(user_id) WHERE user_id IS NOT NULL;

-- Fondateur = super_admin
UPDATE public.coaches SET role = 'super_admin' WHERE id = '3ce49b9e-5447-4890-9853-ba9efa97c308';

-- ────────────────────────────────────────────────────────
-- 1. Fonctions helper
-- ────────────────────────────────────────────────────────

-- Coach ID du user connecté (existe déjà, on recrée pour sécurité)
CREATE OR REPLACE FUNCTION public.get_my_coach_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM public.coaches WHERE user_id = auth.uid()
$$;

-- Est-ce un admin ?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.coaches
    WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin')
  )
$$;

-- Client ID du user connecté
CREATE OR REPLACE FUNCTION public.get_my_client_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM public.clients WHERE user_id = auth.uid()
$$;

-- ────────────────────────────────────────────────────────
-- 2. Supprimer TOUTES les anciennes policies
-- ────────────────────────────────────────────────────────
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- ────────────────────────────────────────────────────────
-- 3. COACHES
-- ────────────────────────────────────────────────────────
-- Coach voit son propre profil, admin voit tous les coachs
CREATE POLICY "auth_coaches_select" ON public.coaches
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "auth_coaches_insert" ON public.coaches
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "auth_coaches_update" ON public.coaches
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- ────────────────────────────────────────────────────────
-- 4. CLIENTS
-- ────────────────────────────────────────────────────────
-- Coach : ses clients. Admin : tous. Client auth : son profil.
CREATE POLICY "auth_clients_select" ON public.clients
  FOR SELECT TO authenticated
  USING (
    coach_id = public.get_my_coach_id()
    OR public.is_admin()
    OR (user_id = auth.uid() AND user_id IS NOT NULL)
  );

CREATE POLICY "auth_clients_insert" ON public.clients
  FOR INSERT TO authenticated
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_clients_update" ON public.clients
  FOR UPDATE TO authenticated
  USING (
    coach_id = public.get_my_coach_id()
    OR public.is_admin()
    OR (user_id = auth.uid() AND user_id IS NOT NULL)
  )
  WITH CHECK (
    coach_id = public.get_my_coach_id()
    OR public.is_admin()
    OR (user_id = auth.uid() AND user_id IS NOT NULL)
  );

CREATE POLICY "auth_clients_delete" ON public.clients
  FOR DELETE TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin());

-- Anon : SELECT par token (transition) + UPDATE profil
CREATE POLICY "anon_clients_select" ON public.clients
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_clients_update" ON public.clients
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 5. QUESTIONNAIRES
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_questionnaires_all" ON public.questionnaires
  FOR ALL TO authenticated
  USING (
    client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id())
    OR public.is_admin()
    OR client_id = public.get_my_client_id()
  )
  WITH CHECK (
    client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id())
    OR public.is_admin()
    OR client_id = public.get_my_client_id()
  );

CREATE POLICY "anon_questionnaires_select" ON public.questionnaires
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_questionnaires_insert" ON public.questionnaires
  FOR INSERT TO anon WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 6. PLANS (macros — pas de coach_id)
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_plans_all" ON public.plans
  FOR ALL TO authenticated
  USING (
    client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id())
    OR public.is_admin()
    OR client_id = public.get_my_client_id()
  )
  WITH CHECK (
    client_id IN (SELECT id FROM public.clients WHERE coach_id = public.get_my_coach_id())
    OR public.is_admin()
  );

CREATE POLICY "anon_plans_select" ON public.plans
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 7. PLANS_FULL
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_plans_full_all" ON public.plans_full
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_plans_full_client" ON public.plans_full
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "anon_plans_full_select" ON public.plans_full
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 8. DAILY_LOGS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_daily_logs_coach" ON public.daily_logs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_daily_logs_client_select" ON public.daily_logs
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "auth_daily_logs_client_insert" ON public.daily_logs
  FOR INSERT TO authenticated
  WITH CHECK (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "auth_daily_logs_client_update" ON public.daily_logs
  FOR UPDATE TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL)
  WITH CHECK (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "anon_daily_logs_select" ON public.daily_logs
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_daily_logs_insert" ON public.daily_logs
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_daily_logs_update" ON public.daily_logs
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 9. BILANS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_bilans_coach" ON public.bilans
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_bilans_client_select" ON public.bilans
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "auth_bilans_client_insert" ON public.bilans
  FOR INSERT TO authenticated
  WITH CHECK (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "anon_bilans_select" ON public.bilans
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_bilans_insert" ON public.bilans
  FOR INSERT TO anon WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 10. TRAIN_LOGS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_train_logs_coach" ON public.train_logs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_train_logs_client_select" ON public.train_logs
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "auth_train_logs_client_insert" ON public.train_logs
  FOR INSERT TO authenticated
  WITH CHECK (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "anon_train_logs_select" ON public.train_logs
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_train_logs_insert" ON public.train_logs
  FOR INSERT TO anon WITH CHECK (true);

-- ────────────────────────────────────────────────────────
-- 11. PROGRAMS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_programs_coach" ON public.programs
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_programs_client" ON public.programs
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);

CREATE POLICY "anon_programs_select" ON public.programs
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 12. EXERCISES
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_exercises_coach" ON public.exercises
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

-- Client : lire les exercices de son coach
CREATE POLICY "auth_exercises_client" ON public.exercises
  FOR SELECT TO authenticated
  USING (
    coach_id = (SELECT coach_id FROM public.clients WHERE id = public.get_my_client_id())
    AND public.get_my_client_id() IS NOT NULL
  );

CREATE POLICY "anon_exercises_select" ON public.exercises
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 13. SEANCES
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_seances_coach" ON public.seances
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "anon_seances_select" ON public.seances
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 14. ALIMENTS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_aliments_coach" ON public.aliments
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_aliments_client" ON public.aliments
  FOR SELECT TO authenticated
  USING (
    coach_id = (SELECT coach_id FROM public.clients WHERE id = public.get_my_client_id())
    AND public.get_my_client_id() IS NOT NULL
  );

CREATE POLICY "anon_aliments_select" ON public.aliments
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 15. REPAS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_repas_coach" ON public.repas
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "anon_repas_select" ON public.repas
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 16. MODULES
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_modules_coach" ON public.modules
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

CREATE POLICY "auth_modules_client" ON public.modules
  FOR SELECT TO authenticated
  USING (
    coach_id = (SELECT coach_id FROM public.clients WHERE id = public.get_my_client_id())
    AND public.get_my_client_id() IS NOT NULL
  );

CREATE POLICY "anon_modules_select" ON public.modules
  FOR SELECT TO anon USING (true);

-- ────────────────────────────────────────────────────────
-- 17. ROADMAPS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_roadmaps_coach" ON public.roadmaps
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

-- ────────────────────────────────────────────────────────
-- 18. SETTINGS
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_settings_coach" ON public.settings
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

-- ────────────────────────────────────────────────────────
-- 19. TEAM
-- ────────────────────────────────────────────────────────
CREATE POLICY "auth_team_coach" ON public.team
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
