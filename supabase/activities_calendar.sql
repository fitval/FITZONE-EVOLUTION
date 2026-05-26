-- ============================================================
-- FITZONE EVOLUTION — Activities & Calendar
-- ============================================================
-- 1. train_logs.type : discriminer strength/running/activity
-- 2. calendar_events : événements planifiés par le coach
-- 3. settings.activity_types : types d'activités personnalisables
-- 4. RLS + RPCs pour accès client
-- ============================================================

-- ────────────────────────────────────────────────────────
-- 1. Colonne type sur train_logs
-- ────────────────────────────────────────────────────────
ALTER TABLE public.train_logs
  ADD COLUMN IF NOT EXISTS type TEXT DEFAULT NULL;

-- ────────────────────────────────────────────────────────
-- 2. Table calendar_events
-- ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.calendar_events (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES public.coaches(id) NOT NULL,
  client_id UUID REFERENCES public.clients(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  time_start TEXT,
  time_end TEXT,
  event_type TEXT NOT NULL DEFAULT 'session',
  color TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ────────────────────────────────────────────────────────
-- 3. Types d'activités dans settings
-- ────────────────────────────────────────────────────────
ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS activity_types JSONB
  DEFAULT '["Natation","Randonnée","Vélo","Course à pied","Marche","Yoga","Pilates","Danse","Escalade","Tennis","Football","Basketball","Arts martiaux","Ski","Surf","Autre"]';

-- ────────────────────────────────────────────────────────
-- 4. RLS sur calendar_events
-- ────────────────────────────────────────────────────────
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_calendar_events_all" ON public.calendar_events
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

CREATE POLICY "client_read_calendar_events" ON public.calendar_events
  FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- ────────────────────────────────────────────────────────
-- 5. RPC : client récupère ses événements calendrier (anon)
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_get_calendar_events(p_token TEXT)
RETURNS SETOF public.calendar_events
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;
  RETURN QUERY
    SELECT * FROM public.calendar_events
    WHERE client_id = v_client_id
    ORDER BY date DESC
    LIMIT 90;
END;
$$;
GRANT EXECUTE ON FUNCTION public.client_get_calendar_events TO anon, authenticated;

-- ────────────────────────────────────────────────────────
-- 6. RPC : client insère une activité (anon)
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_insert_activity(
  p_token TEXT,
  p_activity_type TEXT,
  p_date TEXT,
  p_duration_min INTEGER DEFAULT NULL,
  p_distance_km NUMERIC DEFAULT NULL,
  p_rpe INTEGER DEFAULT NULL,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_row RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.train_logs (coach_id, client_id, session_name, date, type, exercises, comment)
  VALUES (
    v_client.coach_id, v_client.id,
    p_activity_type, p_date::date, 'activity',
    jsonb_build_array(jsonb_build_object(
      'type', 'activity',
      'activity_type', p_activity_type,
      'duration_min', p_duration_min,
      'distance_km', p_distance_km,
      'rpe', p_rpe
    )),
    p_comment
  )
  RETURNING * INTO v_row;

  RETURN row_to_json(v_row);
END;
$$;
GRANT EXECUTE ON FUNCTION public.client_insert_activity TO anon, authenticated;

-- ────────────────────────────────────────────────────────
-- 7. Index pour requêtes calendrier
-- ────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_train_logs_client_date ON public.train_logs(client_id, date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_client_date ON public.calendar_events(client_id, date);
