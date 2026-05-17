-- ============================================================
-- PLAN SWAPS — Permet au client de remplacer un aliment de son
-- plan alimentaire par un équivalent. Stocké côté client, sans
-- toucher au plan original du coach.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.plan_swaps (
  id BIGSERIAL PRIMARY KEY,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  plan_id BIGINT NOT NULL REFERENCES public.plans_full(id) ON DELETE CASCADE,
  day_idx INT NOT NULL,
  repas_idx INT NOT NULL,
  alim_idx INT NOT NULL,
  original_nom TEXT,
  alim JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (client_id, plan_id, day_idx, repas_idx, alim_idx)
);

CREATE INDEX IF NOT EXISTS idx_plan_swaps_client ON public.plan_swaps(client_id);
CREATE INDEX IF NOT EXISTS idx_plan_swaps_plan ON public.plan_swaps(plan_id);

ALTER TABLE public.plan_swaps ENABLE ROW LEVEL SECURITY;

-- Le client authentifié gère ses propres swaps
DROP POLICY IF EXISTS "client_plan_swaps_self" ON public.plan_swaps;
CREATE POLICY "client_plan_swaps_self" ON public.plan_swaps
  FOR ALL TO authenticated
  USING (client_id = public.get_my_client_id())
  WITH CHECK (client_id = public.get_my_client_id());

-- Le coach peut consulter (lecture) les swaps de ses clients
DROP POLICY IF EXISTS "coach_plan_swaps_read" ON public.plan_swaps;
CREATE POLICY "coach_plan_swaps_read" ON public.plan_swaps
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.clients c
      WHERE c.id = plan_swaps.client_id
        AND (c.coach_id = public.get_my_coach_id() OR public.is_admin())
    )
  );

-- ============================================================
-- RPC pour clients anon (accès par token)
-- ============================================================

CREATE OR REPLACE FUNCTION public.client_get_plan_swaps(p_token TEXT)
RETURNS SETOF public.plan_swaps
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'Token invalide'; END IF;
  RETURN QUERY
    SELECT * FROM public.plan_swaps WHERE client_id = v_client_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.client_upsert_plan_swap(
  p_token TEXT,
  p_plan_id BIGINT,
  p_day_idx INT,
  p_repas_idx INT,
  p_alim_idx INT,
  p_original_nom TEXT,
  p_alim JSONB
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'Token invalide'; END IF;

  INSERT INTO public.plan_swaps
    (client_id, plan_id, day_idx, repas_idx, alim_idx, original_nom, alim, updated_at)
  VALUES
    (v_client_id, p_plan_id, p_day_idx, p_repas_idx, p_alim_idx, p_original_nom, p_alim, now())
  ON CONFLICT (client_id, plan_id, day_idx, repas_idx, alim_idx)
  DO UPDATE SET
    alim = EXCLUDED.alim,
    original_nom = EXCLUDED.original_nom,
    updated_at = now();

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_get_plan_swaps(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_upsert_plan_swap(TEXT, BIGINT, INT, INT, INT, TEXT, JSONB) TO anon, authenticated;
