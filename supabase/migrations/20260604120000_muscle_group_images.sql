-- Images par groupe musculaire (gérées par le coach dans l'onglet Entraînement).
-- Stockées dans settings sous forme { "Biceps": "<url drive>", "Pectoraux": "...", ... }.
-- Lecture côté client autorisée par la policy SELECT existante sur settings
-- (RLS au niveau ligne : le client lit déjà partner / gamif_levels / activity_types).
ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS muscle_group_images jsonb DEFAULT '{}'::jsonb;
