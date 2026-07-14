-- ============================================================
-- FITZONE EVOLUTION — Compteur de sel client
-- ============================================================
-- Le client peut ajouter une quantité de sel (en grammes) plusieurs
-- fois par jour, depuis le tracking alimentaire OU depuis le plan.
-- Design multi-insert : une ligne par ajout (comme food_logs / water_logs).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.salt_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  date date NOT NULL,
  grams numeric NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_salt_logs_client_date ON public.salt_logs(client_id, date DESC);

ALTER TABLE public.salt_logs ENABLE ROW LEVEL SECURITY;

-- Policy : coach lit les logs de ses clients
DROP POLICY IF EXISTS "coach_read_salt_logs" ON public.salt_logs;
CREATE POLICY "coach_read_salt_logs" ON public.salt_logs
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Policy : client authentifié gère ses propres logs
DROP POLICY IF EXISTS "client_rw_own_salt_logs" ON public.salt_logs;
CREATE POLICY "client_rw_own_salt_logs" ON public.salt_logs
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- Policy : mode anon (client via token, legacy) — insert/select/delete direct
DROP POLICY IF EXISTS "anon_all_salt_logs" ON public.salt_logs;
CREATE POLICY "anon_all_salt_logs" ON public.salt_logs
  FOR ALL TO anon
  USING (true)
  WITH CHECK (true);
