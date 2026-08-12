-- ============================================================
-- FITZONE EVOLUTION — Masquer un plan / un programme au client
-- ============================================================
-- Le coach veut préparer un plan alimentaire ou un programme, le voir
-- dans son dashboard, mais choisir QUAND le client y a accès.
--
-- visible_client = true par défaut → tout l'existant reste visible.
-- ============================================================

ALTER TABLE public.programs   ADD COLUMN IF NOT EXISTS visible_client boolean NOT NULL DEFAULT true;
ALTER TABLE public.plans_full ADD COLUMN IF NOT EXISTS visible_client boolean NOT NULL DEFAULT true;

-- Le masquage doit être réel, pas seulement cosmétique : une policy
-- RESTRICTIVE s'ajoute en AND aux policies existantes, sans les remplacer
-- (donc sans risque de perdre les règles déjà en place).
-- Le coach et l'admin continuent de tout voir ; le client ne reçoit que
-- les lignes visibles.
DROP POLICY IF EXISTS "programs_hidden_from_client" ON public.programs;
CREATE POLICY "programs_hidden_from_client" ON public.programs
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    COALESCE(visible_client, true)
    OR coach_id = public.get_my_coach_id()
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "plans_full_hidden_from_client" ON public.plans_full;
CREATE POLICY "plans_full_hidden_from_client" ON public.plans_full
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    COALESCE(visible_client, true)
    OR coach_id = public.get_my_coach_id()
    OR public.is_admin()
  );

-- Vérification :
-- SELECT policyname, permissive, roles FROM pg_policies
--   WHERE schemaname='public' AND tablename IN ('programs','plans_full')
--   ORDER BY tablename, policyname;
