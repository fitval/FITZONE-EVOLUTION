-- Le client ne peut pas lire settings.muscle_group_images directement (RLS settings
-- restrictive pour les clients). On expose UNIQUEMENT les images muscles d'un coach
-- via une fonction SECURITY DEFINER (même approche que les RPC client_*).
CREATE OR REPLACE FUNCTION public.get_coach_muscle_images(p_coach_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(muscle_group_images, '{}'::jsonb)
  FROM public.settings
  WHERE coach_id = p_coach_id
  LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.get_coach_muscle_images(uuid) TO anon, authenticated;
