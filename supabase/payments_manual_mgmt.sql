-- ============================================================
-- FITZONE EVOLUTION — Gestion manuelle des paiements
-- ============================================================
-- Permet au coach d'ajouter des paiements manuels sans contrat attaché.
-- À exécuter APRÈS contracts_payments.sql.
-- ============================================================

-- Rendre client_contract_id nullable pour supporter les paiements standalone
ALTER TABLE public.payments
  ALTER COLUMN client_contract_id DROP NOT NULL;

-- Colonne optionnelle pour libellé custom
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS label text;
