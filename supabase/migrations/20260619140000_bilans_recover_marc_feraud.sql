-- Récupération de la photo de bilan perdue de Marc Feraud (2026-06-19).
-- La photo avait bien été uploadée sur Drive (dossier GALLERY) mais l'URL
-- n'a jamais été écrite en base : l'upload + UPDATE se faisait en arrière-plan
-- (fire-and-forget) APRÈS la navigation hors de l'écran ; le client a quitté/
-- backgroundé l'app avant la fin → URL perdue. Corrigé côté client.html
-- (upload désormais attendu avant de quitter).
-- Une seule photo retrouvée sur Drive (suffixe _1) — une 2e photo éventuelle
-- n'a jamais fini de s'uploader.
-- Idempotent : ne touche que le bilan dont photos est vide.

WITH recovered(client_key, bilan_date, new_photos) AS (
  VALUES
    ('marc_feraud', date '2026-06-19',
     '["https://drive.google.com/uc?export=view&id=1u9ELvx8pFgcHCOM0znWuPKrvjeflZvVt"]'::jsonb)
)
UPDATE public.bilans b
SET photos = r.new_photos
FROM recovered r
JOIN public.clients c
  ON lower(replace(c.first_name || '_' || c.last_name, ' ', '_')) = r.client_key
WHERE b.client_id = c.id
  AND b.date = r.bilan_date
  AND (b.photos IS NULL OR b.photos = '[]'::jsonb);
