-- ============================================================
-- Recruitment forms : texte du bouton d'envoi + action après validation
-- ============================================================
-- submit_button_text : libellé du bouton d'envoi du formulaire (défaut "Envoyer ma candidature")
-- success_action     : 'none'     -> écran de remerciement simple
--                      'button'   -> écran de remerciement + bouton vers un lien (comportement historique)
--                      'redirect' -> redirection automatique vers success_button_url après l'envoi

ALTER TABLE recruitment_forms
  ADD COLUMN IF NOT EXISTS submit_button_text TEXT,
  ADD COLUMN IF NOT EXISTS success_action     TEXT NOT NULL DEFAULT 'none';

-- Contrainte de valeurs (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'recruitment_forms_success_action_chk'
  ) THEN
    ALTER TABLE recruitment_forms
      ADD CONSTRAINT recruitment_forms_success_action_chk
      CHECK (success_action IN ('none','button','redirect'));
  END IF;
END$$;

-- Rétro-compat : les formulaires qui ont déjà un lien de bouton gardent le mode "bouton"
UPDATE recruitment_forms
   SET success_action = 'button'
 WHERE success_action = 'none'
   AND success_button_url IS NOT NULL
   AND success_button_url <> '';
