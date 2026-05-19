-- BUG : client_upsert_daily_log déclarait p_existing_id UUID, mais
-- daily_logs.id est en réalité un bigint. Quand le front (mode anon
-- ou auth) appelait la RPC avec un existing.id (bigint sérialisé en
-- chaîne), Postgres tentait de le caster en UUID et plantait avec
-- "operator does not exist: uuid = text".
-- Cas observé : Anthony Laurent (mode anon via token) ne pouvait pas
-- ré-enregistrer un rapport quotidien dès qu'un daily_log existait
-- déjà pour la date (chemin UPDATE).

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
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
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
