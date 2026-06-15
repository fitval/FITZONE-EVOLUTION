-- ════════════════════════════════════════════════════════════════
-- Aliments ajoutés par les clients (non vérifiés)
-- Un client peut ajouter un aliment absent de la base lors du tracking.
-- L'aliment est rangé dans une catégorie spéciale et marqué non vérifié,
-- le coach pourra le valider ensuite depuis le dashboard.
-- 2026-06-15
-- ════════════════════════════════════════════════════════════════

-- 1) Nouvelles colonnes sur aliments
ALTER TABLE public.aliments ADD COLUMN IF NOT EXISTS photo TEXT;
ALTER TABLE public.aliments ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT true;
ALTER TABLE public.aliments ADD COLUMN IF NOT EXISTS added_by_client UUID REFERENCES public.clients(id) ON DELETE SET NULL;

-- Les aliments existants (créés par le coach) restent vérifiés
UPDATE public.aliments SET verified = true WHERE verified IS NULL;

-- 2) Policy : un client authentifié peut INSÉRER un aliment NON vérifié
--    chez SON coach uniquement (les coachs gardent leur policy FOR ALL existante).
DROP POLICY IF EXISTS "auth_aliments_client_insert" ON public.aliments;
CREATE POLICY "auth_aliments_client_insert" ON public.aliments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.get_my_client_id() IS NOT NULL
    AND verified = false
    AND added_by_client = public.get_my_client_id()
    AND coach_id = (SELECT coach_id FROM public.clients WHERE id = public.get_my_client_id())
  );
