-- ============================================================
-- FITZONE EVOLUTION — Food tracking client
-- ============================================================
-- Permet au client de logger manuellement les aliments consommés.
-- Run dans Supabase SQL Editor.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.food_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  date date NOT NULL,
  meal text NOT NULL DEFAULT 'Déjeuner',
  aliment_nom text NOT NULL,
  qte_g numeric NOT NULL DEFAULT 100,
  kcal numeric,
  prot numeric,
  carb numeric,
  fat numeric,
  aliment_id uuid, -- référence optionnelle à aliments.id (snapshot)
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_logs_client_date ON public.food_logs(client_id, date DESC);

ALTER TABLE public.food_logs ENABLE ROW LEVEL SECURITY;

-- Policy : coach lit ses clients
DROP POLICY IF EXISTS "coach_read_food_logs" ON public.food_logs;
CREATE POLICY "coach_read_food_logs" ON public.food_logs
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Policy : client authentifié gère ses propres logs
DROP POLICY IF EXISTS "client_rw_own_food_logs" ON public.food_logs;
CREATE POLICY "client_rw_own_food_logs" ON public.food_logs
  FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- Policy : mode anon (client via token) — lit/écrit/supprime ses logs
-- via RPC (plus sûr). Pour MVP on autorise insert/select direct.
DROP POLICY IF EXISTS "anon_all_food_logs" ON public.food_logs;
CREATE POLICY "anon_all_food_logs" ON public.food_logs
  FOR ALL TO anon
  USING (true)
  WITH CHECK (true);
