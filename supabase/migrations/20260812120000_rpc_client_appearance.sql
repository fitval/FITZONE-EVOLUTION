-- ============================================================
-- FITZONE EVOLUTION — Apparence de l'app client (couleur + thème)
-- ============================================================
-- Le coach choisit la couleur de marque et le thème depuis
-- Réglages > Apparence (settings.client_brand_color / client_theme).
-- Côté client, la lecture directe de `settings` est bloquée par la RLS
-- (même souci que muscle_group_images, cf. 20260605180000_rpc_muscle_images.sql),
-- donc la couleur choisie ne remontait jamais dans l'app : elle restait dorée.
--
-- On expose UNIQUEMENT ces deux champs via une fonction SECURITY DEFINER.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_coach_appearance(p_coach_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'client_brand_color', COALESCE(client_brand_color, '#c49a2a'),
    'client_theme',       COALESCE(client_theme, 'light')
  )
  FROM public.settings
  WHERE coach_id = p_coach_id
  LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.get_coach_appearance(uuid) TO anon, authenticated;
