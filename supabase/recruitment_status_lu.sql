-- ============================================================
-- FITZONE EVOLUTION — Ajout du statut 'lu' aux candidatures
-- ============================================================
-- L'UI propose le statut "Lu" mais la contrainte CHECK ne l'autorisait
-- pas → toute mise à jour vers 'lu' échouait silencieusement.
-- ============================================================

ALTER TABLE public.recruitment_responses
  DROP CONSTRAINT IF EXISTS recruitment_responses_status_check;

ALTER TABLE public.recruitment_responses
  ADD CONSTRAINT recruitment_responses_status_check
  CHECK (status IN ('en_attente','lu','contacte','reserve','accepte','refuse'));
