-- ============================================================
-- FITZONE EVOLUTION — Colonne extra_questions sur questionnaires
-- ============================================================
-- Stocke les réponses aux questions d'intégration custom définies
-- par le coach (via Questionnaires → Intégration).
-- ============================================================

ALTER TABLE public.questionnaires
  ADD COLUMN IF NOT EXISTS extra_questions JSONB DEFAULT NULL;
