-- ============================================================
-- FITZONE EVOLUTION — Récap hebdomadaire IA de la fiche client
-- ============================================================
-- 1) meal_checks : les repas cochés par le client dans son menu.
--    Jusqu'ici cette coche vivait UNIQUEMENT en localStorage (client.html,
--    mealCheckKey) — donc invisible côté coach. On la persiste pour pouvoir
--    dire « il a validé 12 repas sur 21 cette semaine ».
--    ⚠️ L'historique d'avant cette migration n'existe pas : le récap ne compte
--    les repas validés qu'à partir de sa mise en service.
--
-- 2) ai_recaps : cache du résumé rédigé par l'IA, une ligne par client et par
--    semaine (lundi). Évite de rappeler l'API à chaque ouverture de l'onglet.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.meal_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  date date NOT NULL,
  plan_id text NOT NULL,
  day_idx int NOT NULL,
  meal_idx int NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (client_id, date, plan_id, day_idx, meal_idx)
);

CREATE INDEX IF NOT EXISTS idx_meal_checks_client_date ON public.meal_checks(client_id, date DESC);

ALTER TABLE public.meal_checks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_read_meal_checks" ON public.meal_checks;
CREATE POLICY "coach_read_meal_checks" ON public.meal_checks
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "client_rw_own_meal_checks" ON public.meal_checks;
CREATE POLICY "client_rw_own_meal_checks" ON public.meal_checks
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_recaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  week_start date NOT NULL,          -- lundi de la semaine résumée
  stats jsonb DEFAULT '{}'::jsonb,   -- chiffres bruts au moment de la génération
  summary text,                      -- texte rédigé par l'IA
  created_at timestamptz DEFAULT now(),
  UNIQUE (client_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_ai_recaps_client_week ON public.ai_recaps(client_id, week_start DESC);

ALTER TABLE public.ai_recaps ENABLE ROW LEVEL SECURITY;

-- Le récap est un outil du coach : lui seul y accède (le client ne le voit pas).
DROP POLICY IF EXISTS "coach_all_ai_recaps" ON public.ai_recaps;
CREATE POLICY "coach_all_ai_recaps" ON public.ai_recaps
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));
