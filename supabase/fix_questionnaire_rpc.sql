-- Fix: rewrite client_insert_questionnaire to avoid jsonb_populate_record uuid cast issue
CREATE OR REPLACE FUNCTION public.client_insert_questionnaire(
  p_token TEXT,
  p_data JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
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
