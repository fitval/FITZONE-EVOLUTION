-- ============================================================
-- FITZONE EVOLUTION — Retours coach sur le tracking alimentaire
-- ============================================================
-- Le coach voit l'historique tracking du client (food_logs) dans le
-- calendrier et peut écrire un retour par jour. Le retour n'est visible
-- côté client que lorsqu'il est PUBLIÉ (bouton "Envoyer au client").
-- Un seul retour par (coach, client, date) — upsert.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.food_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  date date NOT NULL,
  note text,
  published boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (coach_id, client_id, date)
);

CREATE INDEX IF NOT EXISTS idx_food_feedback_client_date ON public.food_feedback(client_id, date DESC);

ALTER TABLE public.food_feedback ENABLE ROW LEVEL SECURITY;

-- Coach : gère tous les retours de ses clients
DROP POLICY IF EXISTS "coach_all_food_feedback" ON public.food_feedback;
CREATE POLICY "coach_all_food_feedback" ON public.food_feedback
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Client : lit uniquement les retours PUBLIÉS qui le concernent
DROP POLICY IF EXISTS "client_read_published_food_feedback" ON public.food_feedback;
CREATE POLICY "client_read_published_food_feedback" ON public.food_feedback
  FOR SELECT TO authenticated
  USING (published = true AND client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
