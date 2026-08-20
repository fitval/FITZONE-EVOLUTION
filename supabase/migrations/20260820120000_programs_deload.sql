-- ============================================================
-- FITZONE EVOLUTION — Mode deload / phase éphémère sur un programme
-- ============================================================
-- Le coach peut alléger temporairement un programme (dévolume) sans
-- toucher au programme lui-même : sur 1, 2, 3… semaines, on retire des
-- séries effectives sur tout ou partie des exercices. La config expire
-- toute seule à la fin de la fenêtre — le programme d'origine reprend.
--
-- deload = {
--   "active": true,
--   "start":  "2026-08-24",   -- 1er jour (inclus)
--   "weeks":  2,              -- durée en semaines
--   "sets":   -1,             -- séries retirées par défaut (négatif)
--   "note":   "Semaine de décharge — garde les charges",
--   "exos":   { "developpe couche": -2 }   -- override par exercice (clé normalisée)
-- }
--   NULL / {"active":false} → programme normal (cas par défaut).
-- ============================================================

ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS deload jsonb;

COMMENT ON COLUMN public.programs.deload IS
  'Phase éphémère (deload) : fenêtre de dates + séries retirées par exercice. NULL = programme normal.';

-- Vérification :
-- SELECT id, nom, deload FROM public.programs WHERE deload IS NOT NULL;
