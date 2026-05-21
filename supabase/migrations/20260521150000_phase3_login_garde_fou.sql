-- Phase 3 : garde-fou pour les clients qui arrivent avec un vieux lien
-- ?token=... après suppression du mode anon dans client.html.
-- La RPC est accessible en anon, prend un token, et renvoie au front
-- l'email du client + s'il a un compte. Le front enchaîne avec un appel
-- à l'edge function send-email pour envoyer un mail de recovery
-- (définition de mot de passe). Cas où le client n'a pas encore de
-- compte auth : le front affiche un message demandant de contacter le
-- coach (impossible d'inviter en anon sans risque).

CREATE OR REPLACE FUNCTION public.client_request_login_email(p_token TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, email, user_id, first_name
  INTO v_client
  FROM public.clients
  WHERE token = p_token::uuid;

  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  RETURN json_build_object(
    'success',     true,
    'has_account', v_client.user_id IS NOT NULL,
    'email',       v_client.email,
    'first_name',  v_client.first_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_request_login_email(text) TO anon, authenticated;
