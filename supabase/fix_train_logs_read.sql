-- RPC pour lire les train_logs en mode anon (token-based)
-- Corrige le bug: les clients anon ne voient pas leurs anciennes perfs

CREATE OR REPLACE FUNCTION public.client_get_train_logs(p_token TEXT)
RETURNS SETOF public.train_logs
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id uuid;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token;
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

GRANT EXECUTE ON FUNCTION public.client_get_train_logs TO anon;
GRANT EXECUTE ON FUNCTION public.client_get_train_logs TO authenticated;
