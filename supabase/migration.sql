-- =============================================
-- FITZONE EVOLUTION — Migration localStorage → Supabase
-- Exécuter ce SQL dans le SQL Editor de Supabase
-- =============================================

-- Bibliothèque exercices
CREATE TABLE IF NOT EXISTS exercises (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  muscle TEXT,
  equip TEXT,
  video TEXT,
  sets TEXT,
  sets_data JSONB DEFAULT '[]',
  notes TEXT,
  replacements JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Programmes d'entraînement
CREATE TABLE IF NOT EXISTS programs (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  tags JSONB DEFAULT '[]',
  description TEXT,
  jours JSONB DEFAULT '[]',
  client_id UUID REFERENCES clients(id),
  client_nom TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Séances
CREATE TABLE IF NOT EXISTS seances (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  tags JSONB DEFAULT '[]',
  notes TEXT,
  warmup JSONB DEFAULT '[]',
  workout JSONB DEFAULT '[]',
  cooldown JSONB DEFAULT '[]',
  client_id UUID REFERENCES clients(id),
  client_nom TEXT,
  prog_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Base aliments
CREATE TABLE IF NOT EXISTS aliments (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  cat TEXT,
  source TEXT,
  kcal NUMERIC DEFAULT 0,
  prot NUMERIC DEFAULT 0,
  carb NUMERIC DEFAULT 0,
  fat NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Templates repas/recettes
CREATE TABLE IF NOT EXISTS repas (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  type TEXT,
  instr TEXT,
  items JSONB DEFAULT '[]',
  kcal NUMERIC DEFAULT 0,
  prot NUMERIC DEFAULT 0,
  carb NUMERIC DEFAULT 0,
  fat NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Plans nutrition complets
CREATE TABLE IF NOT EXISTS plans_full (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  nom TEXT NOT NULL,
  type TEXT DEFAULT 'full',
  jours JSONB DEFAULT '[]',
  client_id UUID REFERENCES clients(id),
  client_nom TEXT,
  notes TEXT,
  kcal NUMERIC DEFAULT 0,
  prot NUMERIC DEFAULT 0,
  carb NUMERIC DEFAULT 0,
  fat NUMERIC DEFAULT 0,
  source TEXT,
  config JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Modules de formation
CREATE TABLE IF NOT EXISTS modules (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  title TEXT NOT NULL,
  cat TEXT,
  access TEXT,
  description TEXT,
  img TEXT,
  chapitres JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Équipe coaching
CREATE TABLE IF NOT EXISTS team (
  id BIGINT PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  role TEXT,
  color TEXT,
  clients_data JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Paramètres coach
CREATE TABLE IF NOT EXISTS settings (
  coach_id UUID REFERENCES coaches(id) PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  gym TEXT,
  data JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Roadmap 52 semaines
CREATE TABLE IF NOT EXISTS roadmaps (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  weeks JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(coach_id, client_id)
);

-- Logs quotidiens (progression)
CREATE TABLE IF NOT EXISTS daily_logs (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  date DATE NOT NULL,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Logs entraînement
CREATE TABLE IF NOT EXISTS train_logs (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  session_name TEXT,
  date DATE,
  cycle TEXT,
  exercises JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Bilans clients
CREATE TABLE IF NOT EXISTS bilans (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID REFERENCES coaches(id) NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  titre TEXT,
  date DATE,
  poids TEXT,
  contenu TEXT,
  photos JSONB DEFAULT '[]',
  reponses JSONB,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- Activer RLS sur toutes les nouvelles tables
-- =============================================
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE seances ENABLE ROW LEVEL SECURITY;
ALTER TABLE aliments ENABLE ROW LEVEL SECURITY;
ALTER TABLE repas ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans_full ENABLE ROW LEVEL SECURITY;
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE team ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE roadmaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE train_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bilans ENABLE ROW LEVEL SECURITY;

-- =============================================
-- Colonnes manquantes (correctif)
-- =============================================
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS reps TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS rest TEXT;
ALTER TABLE modules ADD COLUMN IF NOT EXISTS "desc" TEXT;

-- Politique : tout le monde peut lire/écrire (via anon key + auth)
-- À renforcer plus tard avec des politiques par coach_id
CREATE POLICY "Allow all for authenticated" ON exercises FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON programs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON seances FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON aliments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON repas FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON plans_full FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON modules FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON team FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON settings FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON roadmaps FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON daily_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON train_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON bilans FOR ALL TO authenticated USING (true) WITH CHECK (true);
