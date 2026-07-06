-- ============================================================
-- FITZONE EVOLUTION — Objectif d'hydratation par client
-- ============================================================
-- Le coach définit l'objectif d'eau (mL/jour) du client depuis la
-- fiche client (onglet Nutrition), stocké dans la table plans à côté
-- des objectifs macros. Lu côté client pour le compteur d'eau.
-- ============================================================

ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS water_goal_ml numeric;
