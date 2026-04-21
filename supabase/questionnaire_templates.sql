-- ============================================================
-- FITZONE EVOLUTION — Templates de questionnaires personnalisables
-- ============================================================
-- Ajoute 3 colonnes JSONB à la table settings pour stocker les
-- questionnaires éditables par le coach.
--
-- Structure attendue pour chaque JSON (array de questions) :
-- [
--   {
--     "id": "q1",
--     "section": "ATTITUDE",         -- optionnel, section/groupe visuel
--     "icon": "fa-brain",             -- optionnel, font-awesome icon
--     "label": "Question ?",          -- texte affiché
--     "type": "text" | "textarea" | "rating" | "number" | "yesno" | "choice",
--     "scale": 5 | 10,                -- pour type rating
--     "unit": "kg" | "cm" | "%",      -- pour type number
--     "options": ["Oui","Non"],       -- pour type choice
--     "required": true | false
--   }
-- ]
--
-- Run dans Supabase SQL Editor.
-- ============================================================

ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS q_bilan JSONB DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS q_daily JSONB DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS q_integration JSONB DEFAULT NULL;

-- La policy anon_read_settings permet déjà au client (via token) de
-- lire les templates. Aucune policy supplémentaire nécessaire.

-- Vérification :
-- SELECT coach_id, q_bilan, q_daily, q_integration FROM settings LIMIT 5;
