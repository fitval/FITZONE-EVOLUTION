-- ════════════════════════════════════════════════════════════════
-- FITZONE EVOLUTION — Messagerie 1-to-1 coach ↔ client
-- 2026-09-01
-- ════════════════════════════════════════════════════════════════
-- Un fil unique par client. Pas de table "conversations" : le couple
-- (coach_id, client_id) EST la conversation. Un client n'a qu'un coach.
--
-- sender : 'coach' | 'client' | 'auto'
--   'auto' = message envoyé par une règle automatique. Il s'affiche
--   côté client exactement comme un message du coach (c'est demandé),
--   mais on garde la distinction en base pour les stats et le récap.
--
-- local_id : uuid généré par le navigateur AVANT l'envoi. Sert à
--   dédoublonner l'affichage optimiste quand l'écho Realtime revient
--   (sinon le message apparaît deux fois). Unique par client.
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  sender text NOT NULL CHECK (sender IN ('coach','client','auto')),
  body text,
  kind text NOT NULL DEFAULT 'text' CHECK (kind IN ('text','image','file')),
  attachment_url text,        -- original (lot 2)
  attachment_thumb text,      -- miniature affichée dans le fil (lot 2)
  attachment_meta jsonb,      -- {name, mime, size, w, h}
  local_id uuid,              -- anti-doublon envoi optimiste ↔ Realtime
  rule_id text,               -- règle automatique à l'origine du message (sender='auto')
  read_by_coach boolean NOT NULL DEFAULT false,
  read_by_client boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Un message a forcément du texte OU une pièce jointe
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_not_empty;
ALTER TABLE public.messages ADD CONSTRAINT messages_not_empty
  CHECK (COALESCE(NULLIF(btrim(body), ''), attachment_url) IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_messages_client_created
  ON public.messages(client_id, created_at DESC);

-- Non-lus côté coach : index partiel, c'est la requête de la liste clients
CREATE INDEX IF NOT EXISTS idx_messages_coach_unread
  ON public.messages(coach_id) WHERE read_by_coach = false;

-- Le même message ne peut pas être inséré deux fois (double tap, retry réseau)
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_local_id
  ON public.messages(client_id, local_id) WHERE local_id IS NOT NULL;

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ── Coach : tout sur les fils de SES clients ────────────────────
DROP POLICY IF EXISTS "coach_all_messages" ON public.messages;
CREATE POLICY "coach_all_messages" ON public.messages
  FOR ALL TO authenticated
  USING (coach_id = public.get_my_coach_id() OR public.is_admin())
  WITH CHECK (coach_id = public.get_my_coach_id() OR public.is_admin());

-- ── Client : lecture de son seul fil ────────────────────────────
DROP POLICY IF EXISTS "client_read_own_messages" ON public.messages;
CREATE POLICY "client_read_own_messages" ON public.messages
  FOR SELECT TO authenticated
  USING (client_id = public.get_my_client_id());

-- ── Client : écriture de ses seuls messages ─────────────────────
-- sender='client' est imposé par la policy : un client ne peut pas
-- fabriquer un message qui s'afficherait comme venant du coach.
DROP POLICY IF EXISTS "client_insert_own_messages" ON public.messages;
CREATE POLICY "client_insert_own_messages" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    client_id = public.get_my_client_id()
    AND sender = 'client'
    AND read_by_client = true
    AND read_by_coach = false
    AND coach_id = (SELECT coach_id FROM public.clients WHERE id = public.get_my_client_id())
  );

-- ── Client : marquer comme lus les messages du coach ────────────
-- UPDATE sans policy = 0 ligne modifiée SANS erreur (piège déjà
-- rencontré sur bilans et client_media). On la pose tout de suite.
-- Le client ne peut toucher qu'au drapeau read_by_client : les autres
-- colonnes sont figées par le trigger ci-dessous.
DROP POLICY IF EXISTS "client_update_read_flag" ON public.messages;
CREATE POLICY "client_update_read_flag" ON public.messages
  FOR UPDATE TO authenticated
  USING (client_id = public.get_my_client_id())
  WITH CHECK (client_id = public.get_my_client_id());

CREATE OR REPLACE FUNCTION public.messages_client_update_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Le coach (et l'admin) modifient librement ; on ne bride que le client.
  IF public.get_my_coach_id() IS NOT NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.coach_id  IS DISTINCT FROM OLD.coach_id
     OR NEW.client_id IS DISTINCT FROM OLD.client_id
     OR NEW.sender    IS DISTINCT FROM OLD.sender
     OR NEW.body      IS DISTINCT FROM OLD.body
     OR NEW.kind      IS DISTINCT FROM OLD.kind
     OR NEW.attachment_url   IS DISTINCT FROM OLD.attachment_url
     OR NEW.attachment_thumb IS DISTINCT FROM OLD.attachment_thumb
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Un client ne peut modifier que le statut de lecture';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_messages_client_update_guard ON public.messages;
CREATE TRIGGER trg_messages_client_update_guard
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_client_update_guard();

-- ── Temps réel ──────────────────────────────────────────────────
-- Sans ça, aucune notification push-websocket : le fil ne se mettrait
-- à jour qu'au rechargement de la page.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- REPLICA IDENTITY FULL : sinon les événements UPDATE (passage en "lu")
-- arrivent sans les colonnes non modifiées côté client.
ALTER TABLE public.messages REPLICA IDENTITY FULL;
