-- ============================================================
-- FITZONE EVOLUTION — Médias ajoutés par le coach dans la galerie
-- ============================================================
-- Le coach reçoit souvent les photos de bilan par WhatsApp / mail.
-- Il peut désormais les uploader directement depuis l'onglet Galerie
-- de la fiche client (bouton « Ajouter du contenu »).
--
-- type  : 'photo' (upload Drive) | 'video' (lien YouTube / Drive)
-- url   : URL Drive de la photo, ou lien de la vidéo
-- label : libellé libre affiché sous la vignette ("Bilan semaine 8"…)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.client_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'photo',
  url text NOT NULL,
  date date NOT NULL DEFAULT current_date,
  label text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_media_client_date ON public.client_media(client_id, date DESC);

ALTER TABLE public.client_media ENABLE ROW LEVEL SECURITY;

-- Coach : gère tous les médias de ses clients
DROP POLICY IF EXISTS "coach_all_client_media" ON public.client_media;
CREATE POLICY "coach_all_client_media" ON public.client_media
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Client authentifié : lecture seule de ses propres médias
DROP POLICY IF EXISTS "client_read_own_media" ON public.client_media;
CREATE POLICY "client_read_own_media" ON public.client_media
  FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
