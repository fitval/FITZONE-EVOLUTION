-- Permettre aux clients de SUPPRIMER / MODIFIER leurs activités manuelles
-- ------------------------------------------------------------------------
-- Le client peut déjà créer (auth_train_logs_client_insert) et lire ses
-- train_logs, mais il manquait DELETE et UPDATE → la suppression/édition
-- d'une activité depuis l'app cliente était bloquée en silence par la RLS
-- (0 ligne affectée, sans erreur, l'activité réapparaissait au rechargement).
--
-- Sécurité : limité à SES propres lignes (client_id = get_my_client_id())
-- ET aux activités manuelles uniquement (type = 'activity'), pour qu'un
-- client ne puisse pas supprimer/altérer son historique de séances
-- (type 'strength' / 'running') créé via le suivi d'entraînement.

DROP POLICY IF EXISTS "auth_train_logs_client_delete" ON public.train_logs;
CREATE POLICY "auth_train_logs_client_delete" ON public.train_logs
  FOR DELETE TO authenticated
  USING (
    client_id = public.get_my_client_id()
    AND public.get_my_client_id() IS NOT NULL
    AND type = 'activity'
  );

DROP POLICY IF EXISTS "auth_train_logs_client_update" ON public.train_logs;
CREATE POLICY "auth_train_logs_client_update" ON public.train_logs
  FOR UPDATE TO authenticated
  USING (
    client_id = public.get_my_client_id()
    AND public.get_my_client_id() IS NOT NULL
    AND type = 'activity'
  )
  WITH CHECK (
    client_id = public.get_my_client_id()
    AND public.get_my_client_id() IS NOT NULL
    AND type = 'activity'
  );
