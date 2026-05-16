-- ============================================================
-- FITZONE EVOLUTION — Cron emails via Supabase Vault
-- ============================================================
-- Le job pg_cron précédent embarquait la service_role_key en clair
-- dans cron.job.command (lisible par tout rôle ayant accès à
-- pg_catalog). Cette migration :
--   1. supprime ce job (et la clé qui y traînait)
--   2. recrée le job en lisant la clé depuis vault.decrypted_secrets
--      → la commande visible ne contient plus aucun secret.
--
-- Pour que le job fonctionne, il faut UN secret nommé
-- 'service_role_key_for_cron' dans le Vault. À configurer une seule
-- fois après rotation de la clé (instructions à la fin du fichier).
-- ============================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'fitzone-process-scheduled-emails') THEN
    PERFORM cron.unschedule('fitzone-process-scheduled-emails');
  END IF;
END $$;

SELECT cron.schedule(
  'fitzone-process-scheduled-emails',
  '0 * * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://wsrykmutyhjxdnhnyexl.supabase.co/functions/v1/process-scheduled-emails',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'service_role_key_for_cron'
          LIMIT 1
        ),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $cron$
);

-- ============================================================
-- ÉTAPES MANUELLES (à faire UNE FOIS via le SQL Editor) :
-- ============================================================
-- 1) Roter la service_role secret :
--    Dashboard Supabase → Settings → API → "Reset service_role secret"
--    (récupérer la nouvelle clé)
--
-- 2) Stocker la nouvelle clé dans le Vault :
--    SELECT vault.create_secret(
--      'NOUVELLE_CLE_ICI',
--      'service_role_key_for_cron',
--      'Used by pg_cron job fitzone-process-scheduled-emails'
--    );
--
--    Si le secret existe déjà (ex: ré-exécution), pour le mettre à
--    jour utiliser :
--      UPDATE vault.secrets
--      SET secret = 'NOUVELLE_CLE_ICI'
--      WHERE name = 'service_role_key_for_cron';
-- ============================================================
