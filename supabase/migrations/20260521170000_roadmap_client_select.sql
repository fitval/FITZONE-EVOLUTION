-- Permet au client en mode auth de lire sa propre roadmap.
-- Nécessaire pour afficher les "Objectifs de la semaine" rédigés par
-- le coach dans la page d'accueil de l'app client.

CREATE POLICY "auth_roadmaps_client_select" ON public.roadmaps
  FOR SELECT TO authenticated
  USING (
    client_id = public.get_my_client_id()
    AND public.get_my_client_id() IS NOT NULL
  );
