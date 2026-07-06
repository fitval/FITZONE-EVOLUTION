-- ============================================================
-- FITZONE EVOLUTION — Compteur d'eau / hydratation client
-- ============================================================
-- Le client peut ajouter une quantité d'eau (en mL) plusieurs fois
-- par jour, depuis le tracking alimentaire OU depuis le plan.
-- Design multi-insert : une ligne par ajout (comme food_logs).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.water_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  date date NOT NULL,
  ml numeric NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_water_logs_client_date ON public.water_logs(client_id, date DESC);

ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;

-- Policy : coach lit les logs de ses clients
DROP POLICY IF EXISTS "coach_read_water_logs" ON public.water_logs;
CREATE POLICY "coach_read_water_logs" ON public.water_logs
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Policy : client authentifié gère ses propres logs
DROP POLICY IF EXISTS "client_rw_own_water_logs" ON public.water_logs;
CREATE POLICY "client_rw_own_water_logs" ON public.water_logs
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- Policy : mode anon (client via token, legacy) — insert/select/delete direct
DROP POLICY IF EXISTS "anon_all_water_logs" ON public.water_logs;
CREATE POLICY "anon_all_water_logs" ON public.water_logs
  FOR ALL TO anon
  USING (true)
  WITH CHECK (true);
