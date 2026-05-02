-- ============================================================
-- FITZONE EVOLUTION — Webhooks de notification (per-coach)
-- ============================================================
-- Stocke la liste des webhooks (Discord, Make, Zapier, n8n…) par
-- coach. Chaque entrée :
-- {
--   "id": "w_xxx",
--   "label": "Discord recrutement",
--   "url": "https://...",
--   "events": ["recruitment_response","questionnaire_submitted",...],
--   "enabled": true
-- }
-- ============================================================

ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS notifications JSONB DEFAULT '[]'::jsonb;

-- Les policies existantes sur settings (auth_settings_coach +
-- auth_settings_client_read + anon_read_settings) couvrent ce
-- nouveau champ. Aucune policy supplémentaire nécessaire.
