-- ============================================================
-- FITZONE EVOLUTION — Liquides de cuisson dans le compteur d'eau
-- ============================================================
-- On distingue deux types de liquides dans water_logs :
--   - kind='drink'   : boissons/eau bue directement (comportement actuel)
--   - kind='cooking' : liquides utilisés dans les plats (ex: eau du porridge),
--                      avec un titre libre (label), ex "Avoine 500 ml".
-- Les deux comptent dans le total de liquide consommé.
-- Colonnes ajoutées, valeur par défaut 'drink' → aucune donnée existante cassée.
-- ============================================================

ALTER TABLE public.water_logs
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'drink',
  ADD COLUMN IF NOT EXISTS label text;
