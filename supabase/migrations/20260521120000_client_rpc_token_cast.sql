-- clients.token est uuid. Toutes les RPC SECURITY DEFINER prenant
-- p_token TEXT doivent caster en `p_token::uuid` au moment du
-- WHERE — sinon Postgres plante avec "operator does not exist: uuid = text".
-- Symptôme observé : Anthony Laurent ne pouvait pas enregistrer ses
-- séances (client_insert_train_log) — même pattern que pour saveSuivi
-- corrigé le 2026-05-19.
-- Cette migration aligne TOUTES les RPC client_* connues sur le pattern
-- `token = p_token::uuid`. Les RPC gamification l'utilisaient déjà.

-- ────────────────────────────────────────────────────────
-- 1. client_update_profile
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_update_profile(
  p_token TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_email TEXT,
  p_photo TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  UPDATE public.clients
  SET first_name = p_first_name,
      last_name  = p_last_name,
      email      = p_email,
      photo      = p_photo
  WHERE id = v_client_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- 2. client_update_status
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_update_status(
  p_token TEXT,
  p_status TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  IF p_status NOT IN ('questionnaire_done', 'active') THEN
    RAISE EXCEPTION 'Statut non autorisé';
  END IF;

  UPDATE public.clients SET status = p_status WHERE id = v_client_id;
  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- 3. client_insert_train_log  ← bug Anthony : séances non enregistrées
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_insert_train_log(
  p_token TEXT,
  p_session_name TEXT,
  p_date TEXT,
  p_exercises JSONB,
  p_cycle TEXT DEFAULT NULL,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.train_logs (coach_id, client_id, session_name, date, exercises, cycle, comment)
  VALUES (v_client.coach_id, v_client.id, p_session_name, p_date::date, p_exercises, p_cycle, p_comment);

  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- 4. client_insert_bilan
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_insert_bilan(
  p_token TEXT,
  p_titre TEXT,
  p_date TEXT,
  p_photos JSONB,
  p_reponses JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.bilans (coach_id, client_id, titre, date, photos, reponses, read)
  VALUES (v_client.coach_id, v_client.id, p_titre, p_date::date, p_photos, p_reponses, false);

  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- 5. client_insert_questionnaire
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_insert_questionnaire(
  p_token TEXT,
  p_data JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.questionnaires (
    client_id, coach_id,
    sex, age, height_cm, weight_kg, weight_goal,
    phone, profession, has_children,
    goal, main_goal_detail, goal_deadline,
    motivation_score, why_fitzone, why_coach,
    injuries, medications,
    previous_program, previous_diet,
    supplements_current, supplements_open,
    experience_level, activity_level,
    gym_name, home_equipment,
    training_days, session_duration, disliked_exercises,
    diet_type, meals_per_day, prep_time_max,
    meal_habits, favorite_foods, food_relationship, diet_variations,
    daily_steps, sleep_hours, sleep_quality,
    allergies, extra_info, submitted_at
  ) VALUES (
    v_client.id, v_client.coach_id,
    p_data->>'sex', (p_data->>'age')::INT, (p_data->>'height_cm')::NUMERIC, (p_data->>'weight_kg')::NUMERIC, (p_data->>'weight_goal')::NUMERIC,
    p_data->>'phone', p_data->>'profession', (p_data->>'has_children')::BOOLEAN,
    p_data->>'goal', p_data->>'main_goal_detail', p_data->>'goal_deadline',
    (p_data->>'motivation_score')::INT, p_data->>'why_fitzone', p_data->>'why_coach',
    p_data->>'injuries', p_data->>'medications',
    p_data->>'previous_program', p_data->>'previous_diet',
    p_data->>'supplements_current', (p_data->>'supplements_open')::BOOLEAN,
    p_data->>'experience_level', p_data->>'activity_level',
    p_data->>'gym_name', p_data->>'home_equipment',
    p_data->'training_days', p_data->>'session_duration', p_data->>'disliked_exercises',
    p_data->>'diet_type', p_data->>'meals_per_day', (p_data->>'prep_time_max')::INT,
    p_data->>'meal_habits', p_data->>'favorite_foods', p_data->>'food_relationship', p_data->>'diet_variations',
    (p_data->>'daily_steps')::INT, (p_data->>'sleep_hours')::NUMERIC, (p_data->>'sleep_quality')::BOOLEAN,
    p_data->'allergies', p_data->>'extra_info', (p_data->>'submitted_at')::TIMESTAMPTZ
  );

  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- 6. client_get_train_logs
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_get_train_logs(p_token TEXT)
RETURNS SETOF public.train_logs
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id uuid;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  RETURN QUERY
    SELECT * FROM public.train_logs
    WHERE client_id = v_client_id
    ORDER BY date DESC
    LIMIT 30;
END;
$$;

-- ────────────────────────────────────────────────────────
-- 7. client_get_plan_swaps
-- ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.client_get_plan_swaps(p_token TEXT)
RETURNS SETOF public.plan_swaps
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'Token invalide'; END IF;
  RETURN QUERY
    SELECT * FROM public.plan_swaps WHERE client_id = v_client_id;
END;
$$;

-- ────────────────────────────────────────────────────────
-- 8. client_upsert_plan_swap
-- ────────────────────────────────────────────────────────
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
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token::uuid;
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

-- Re-grant pour être sûr (no-op si déjà accordé)
GRANT EXECUTE ON FUNCTION public.client_update_profile(text, text, text, text, text)             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_update_status(text, text)                                 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_insert_train_log(text, text, text, jsonb, text, text)     TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_insert_bilan(text, text, text, jsonb, jsonb)              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_insert_questionnaire(text, jsonb)                         TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_get_train_logs(text)                                      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_get_plan_swaps(text)                                      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_upsert_plan_swap(text, bigint, int, int, int, text, jsonb) TO anon, authenticated;
