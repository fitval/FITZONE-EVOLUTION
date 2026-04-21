-- ============================================================
-- FITZONE EVOLUTION — Champs pour contrat sur la table clients
-- ============================================================
-- Ajoute date de naissance et adresse postale pour pouvoir les
-- transmettre automatiquement dans les contrats.
-- ============================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS birth_date date,
  ADD COLUMN IF NOT EXISTS address text;
