-- ============================================================
-- FITZONE EVOLUTION — Add multi-client columns to programs & plans_full
-- ============================================================

-- Programs : ajout colonnes multi-client
ALTER TABLE public.programs
  ADD COLUMN IF NOT EXISTS client_ids JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS client_noms JSONB DEFAULT '[]';

-- Plans_full : ajout colonnes multi-client
ALTER TABLE public.plans_full
  ADD COLUMN IF NOT EXISTS client_ids JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS client_noms JSONB DEFAULT '[]';

-- Seances : ajout colonnes multi-client (pour cohérence)
ALTER TABLE public.seances
  ADD COLUMN IF NOT EXISTS client_ids JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS client_noms JSONB DEFAULT '[]';
