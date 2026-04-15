-- Table coach_data : stockage key-value JSONB par coach
-- Utilisé pour synchroniser entre navigateurs les données :
-- - Suivi marketing (key = 'marketing')
-- - Suivi financier (key = 'finance')
-- Extensible pour d'autres données de coach

CREATE TABLE IF NOT EXISTS coach_data (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) ON DELETE CASCADE NOT NULL,
  key TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(coach_id, key)
);

CREATE INDEX IF NOT EXISTS idx_coach_data_coach_key ON coach_data(coach_id, key);

ALTER TABLE coach_data ENABLE ROW LEVEL SECURITY;

-- Chaque coach peut lire/écrire uniquement ses propres données
DROP POLICY IF EXISTS "Coach read own data" ON coach_data;
CREATE POLICY "Coach read own data" ON coach_data
  FOR SELECT
  USING (coach_id IN (SELECT id FROM coaches WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Coach insert own data" ON coach_data;
CREATE POLICY "Coach insert own data" ON coach_data
  FOR INSERT
  WITH CHECK (coach_id IN (SELECT id FROM coaches WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Coach update own data" ON coach_data;
CREATE POLICY "Coach update own data" ON coach_data
  FOR UPDATE
  USING (coach_id IN (SELECT id FROM coaches WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Coach delete own data" ON coach_data;
CREATE POLICY "Coach delete own data" ON coach_data
  FOR DELETE
  USING (coach_id IN (SELECT id FROM coaches WHERE user_id = auth.uid()));
