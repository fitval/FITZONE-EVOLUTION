-- Fix RLS helpers : auth.uid() peut renvoyer text dans certaines sessions,
-- ce qui plante (uuid = text) côté policy quand un client en mode auth
-- (Supabase Auth) écrit sur daily_logs / train_logs / bilans / etc.
-- Cas observé : Anthony Laurent ne pouvait pas enregistrer son rapport quotidien.
-- Le cast explicite est un no-op si auth.uid() est déjà uuid.

CREATE OR REPLACE FUNCTION public.get_my_client_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM public.clients WHERE user_id = (auth.uid())::uuid
$$;

CREATE OR REPLACE FUNCTION public.get_my_coach_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM public.coaches WHERE user_id = (auth.uid())::uuid
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.coaches
    WHERE user_id = (auth.uid())::uuid
      AND role IN ('admin','super_admin')
  )
$$;

-- Autorise les clients connectés en mode auth à appeler les RPC SECURITY DEFINER
-- déjà utilisées en mode anon. Le front route maintenant les écritures
-- daily_logs / train_logs / bilans via ces RPC dans les deux modes,
-- pour un comportement uniforme et résilient aux RLS.
GRANT EXECUTE ON FUNCTION public.client_upsert_daily_log(text, text, jsonb, uuid)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_insert_train_log(text, text, text, jsonb, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_insert_bilan(text, text, text, jsonb, jsonb)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_update_profile(text, text, text, text, text)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_update_status(text, text)                         TO authenticated;
