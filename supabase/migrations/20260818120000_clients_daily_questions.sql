-- ============================================================
-- FITZONE EVOLUTION — Questions du rapport quotidien par client
-- ============================================================
-- Le coach définit ses questions globales dans settings.q_daily.
-- Ici, il peut en désactiver certaines client par client, sans les
-- supprimer et sans toucher à l'historique déjà enregistré.
--
-- daily_questions = tableau JSON des ids de questions ACTIVES.
--   NULL  → toutes les questions du coach sont actives (cas par défaut,
--           donc aucun changement pour les clients existants).
--   []    → aucune question (le client ne voit qu'un rapport vide).
-- ============================================================

ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS daily_questions jsonb;

COMMENT ON COLUMN public.clients.daily_questions IS
  'Ids des questions du rapport quotidien actives pour ce client. NULL = toutes actives.';

-- Vérification :
-- SELECT id, first_name, daily_questions FROM public.clients LIMIT 5;
