-- Fix : photos de bilan invisibles côté coach.
-- Depuis le fix du 2026-05-31 (commit 7a094d0), submitBilan insère le bilan
-- D'ABORD puis ajoute les photos via UPDATE après l'upload Drive en arrière-plan.
-- Or il n'existait AUCUNE policy UPDATE sur bilans pour le client authentifié
-- (seulement SELECT + INSERT) → l'update touchait 0 ligne, silencieusement.
-- Les photos partaient bien sur Drive mais leur URL n'était jamais écrite en base.
-- (L'édition d'un bilan existant par le client était cassée de la même façon.)

CREATE POLICY "auth_bilans_client_update" ON public.bilans
  FOR UPDATE TO authenticated
  USING (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL)
  WITH CHECK (client_id = public.get_my_client_id() AND public.get_my_client_id() IS NOT NULL);
