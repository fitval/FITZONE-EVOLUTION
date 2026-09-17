-- ⚠️⚠️⚠️ ANCIEN SCRIPT MANUEL — NE JAMAIS REJOUER, NI EN ENTIER NI PAR MORCEAUX ⚠️⚠️⚠️
-- Ce script réinstalle le droit pour le rôle anonyme d'exécuter client_get_train_logs (ancien mode jeton, supprimé en phase 3).
-- Ces accès ont été fermés en production. L'état de référence des règles RLS est tracé dans :
--   supabase/migrations/20260917120000_rls_etat_reel_corrections_manuelles.sql
-- Pour réparer ou modifier quelque chose : écrire une nouvelle migration ciblée, jamais recoller ce fichier.
-- Conservé pour l'historique uniquement (en-tête ajouté le 17/09/2026).

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
