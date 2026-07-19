-- ============================================================
-- FITZONE EVOLUTION — Objectif hydrique "repas" réglable par le coach
-- ============================================================
-- plans.water_goal_ml      : objectif de consommation (boissons + plats) — existant
-- plans.water_meal_goal_ml : objectif indicatif de liquide utilisé dans les plats
-- Le coach peut régler les deux depuis le calcul nutrition du client.
-- ============================================================

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS water_meal_goal_ml integer;
