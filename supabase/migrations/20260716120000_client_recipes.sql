-- ============================================================
-- FITZONE EVOLUTION — Recettes / repas enregistrés par le client
-- ============================================================
-- Depuis le tracking alimentaire, le client peut enregistrer un repas
-- qu'il vient de logger (tous ses aliments + quantités) sous un nom.
-- Il pourra ensuite le ré-ajouter en un tap sur n'importe quel jour /
-- n'importe quel créneau de repas.
--
-- items = jsonb : [{aliment_nom, aliment_id, qte_g, kcal, prot, carb, fat, extra}]
-- (macros stockées pour 100g, comme dans food_logs)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.client_recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  nom text NOT NULL,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_recipes_client ON public.client_recipes(client_id, created_at DESC);

ALTER TABLE public.client_recipes ENABLE ROW LEVEL SECURITY;

-- Policy : coach lit les recettes de ses clients
DROP POLICY IF EXISTS "coach_read_client_recipes" ON public.client_recipes;
CREATE POLICY "coach_read_client_recipes" ON public.client_recipes
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Policy : client authentifié gère ses propres recettes
DROP POLICY IF EXISTS "client_rw_own_recipes" ON public.client_recipes;
CREATE POLICY "client_rw_own_recipes" ON public.client_recipes
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
