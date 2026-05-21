-- Stockage des "objectifs en cours" du client avec leurs dates d'application.
-- Le coach les édite dans l'onglet Roadmap, le client les voit en page d'accueil
-- tant que today ∈ [start_date, end_date] (end_date NULL = sans date de fin).
-- Structure : [{ "text": "...", "start_date": "2026-05-21", "end_date": "2026-05-23"|null }, ...]

ALTER TABLE public.roadmaps
  ADD COLUMN IF NOT EXISTS objectifs JSONB DEFAULT '[]'::jsonb;
