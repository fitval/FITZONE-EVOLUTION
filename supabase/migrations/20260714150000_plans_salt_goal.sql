-- ============================================================
-- FITZONE EVOLUTION — Objectif de sel par client
-- ============================================================
-- Le coach définit la limite de sel (g/jour) du client depuis la
-- fiche client (onglet Nutrition), stockée dans la table plans à côté
-- des objectifs macros. Lue côté client pour le compteur de sel.
-- ============================================================

ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS salt_goal_g numeric;
