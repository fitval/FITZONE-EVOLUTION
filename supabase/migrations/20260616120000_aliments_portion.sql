-- ════════════════════════════════════════════════════════════════
-- Aliments : définition d'une portion
-- Permet de saisir/afficher les macros par portion en plus du /100g.
-- Les macros restent stockées POUR 100g (kcal/prot/carb/fat) — valeur
-- canonique — et on mémorise juste la taille + le nom de la portion.
-- 2026-06-16
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.aliments ADD COLUMN IF NOT EXISTS portion_g NUMERIC;
ALTER TABLE public.aliments ADD COLUMN IF NOT EXISTS portion_label TEXT;
