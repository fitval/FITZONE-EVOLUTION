-- clients.token est de type uuid (pas text). Le param p_token déclaré
-- TEXT cassait la comparaison WHERE token = p_token avec
-- "operator does not exist: uuid = text". Les RPC de gamification
-- font déjà `token = p_token::uuid` — on s'aligne sur le même pattern.

DROP FUNCTION IF EXISTS public.client_upsert_daily_log(text, text, jsonb, bigint);
DROP FUNCTION IF EXISTS public.client_upsert_daily_log(text, text, jsonb, uuid);

CREATE OR REPLACE FUNCTION public.client_upsert_daily_log(
  p_token TEXT,
  p_date TEXT,
  p_data JSONB,
  p_existing_id BIGINT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_owner UUID;
BEGIN
  SELECT id, coach_id INTO v_client
  FROM public.clients
  WHERE token = p_token::uuid;

  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  IF p_existing_id IS NOT NULL THEN
    SELECT client_id INTO v_owner FROM public.daily_logs WHERE id = p_existing_id;
    IF v_owner IS NULL OR v_owner != v_client.id THEN
      RAISE EXCEPTION 'Non autorisé';
    END IF;
    UPDATE public.daily_logs SET data = p_data WHERE id = p_existing_id;
  ELSE
    INSERT INTO public.daily_logs (coach_id, client_id, date, data)
    VALUES (v_client.coach_id, v_client.id, p_date::date, p_data);
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_upsert_daily_log(text, text, jsonb, bigint) TO anon, authenticated;
