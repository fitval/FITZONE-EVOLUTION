-- Récupération des photos de bilans perdues (2026-05-31 → 2026-06-07).
-- Les photos avaient bien été uploadées sur Drive (dossier GALLERY) mais
-- l'UPDATE qui écrivait leurs URLs en base échouait silencieusement
-- (policy RLS UPDATE manquante, corrigée par 20260607120000).
-- Ici on ré-attache les fichiers Drive retrouvés aux bilans correspondants,
-- en matchant client (prénom_nom du nom de fichier) + date du bilan.
-- Idempotent : ne touche que les bilans dont photos est vide.

WITH recovered(client_key, bilan_date, new_photos) AS (
  VALUES
    ('clément_corbiere', date '2026-05-31',
     '["https://drive.google.com/uc?export=view&id=11Shm68q2H2yshWGrCG_WoBqlkmhG1WPa"]'::jsonb),
    ('jean-philippe_mallat-desmortiers', date '2026-05-30',
     '["https://drive.google.com/uc?export=view&id=1YKgBD-H-1W7hnBAUeDOZlZThYuBvfpPw",
       "https://drive.google.com/uc?export=view&id=1DMydnZBEGd1Uz9wSpVL47VZ6fA5NwV12",
       "https://drive.google.com/uc?export=view&id=15UfzopdL9Q0srNftnRLJ3yjXpeSWQowt"]'::jsonb),
    ('jean-philippe_mallat-desmortiers', date '2026-06-06',
     '["https://drive.google.com/uc?export=view&id=1xPq1s988Bvb72NXIpOj6zSHhNsP6Dloj",
       "https://drive.google.com/uc?export=view&id=1U6pKA1TCSg554cMJ_bbZ-MmhO_ze9qDs"]'::jsonb),
    ('matys_hoffman', date '2026-06-06',
     '["https://drive.google.com/uc?export=view&id=1pt9iHJilv9SjT6y4IGxxLk2jR1TJw9Pa",
       "https://drive.google.com/uc?export=view&id=1NoWFdX5JwoTkL6JlwLAY4hufcay9Cxjq",
       "https://drive.google.com/uc?export=view&id=1jedKACv9CcVpr5lLXQo9LG_UTNktGLoa",
       "https://drive.google.com/uc?export=view&id=19zY3xCJFHaQE-RQIqnuzFwRItDtVQ5jM",
       "https://drive.google.com/uc?export=view&id=1tk7hk48EHgUmGCs0TqqEo9RBfWb-mK12",
       "https://drive.google.com/uc?export=view&id=1mWTIZ00smT5v_GLp8CSLEQFC3AqaGNVf",
       "https://drive.google.com/uc?export=view&id=18rlDXNglaJ3CEqasm0BLeQn7qTslBjWW"]'::jsonb),
    -- Anthony : fichiers _1.._4 + _6.._8 retrouvés sur Drive (le _5 n'a jamais été uploadé)
    ('anthony_laurent', date '2026-06-07',
     '["https://drive.google.com/uc?export=view&id=1p06wmH-GJC8BjS0UMC-ZTMj9Z96m5b6s",
       "https://drive.google.com/uc?export=view&id=1TfgfYFBCZ6WzTEE4WGgp1BZE69GVm26t",
       "https://drive.google.com/uc?export=view&id=1sLedH-grCIiwvNBXvR6zUJbbQGl1jgZc",
       "https://drive.google.com/uc?export=view&id=1-Fcg3wPrJLMIwpV2OPOYNYY2NlHPs7NW",
       "https://drive.google.com/uc?export=view&id=1j8UQYbdyut6PNHkWiIRRbADWXlFOYyqA",
       "https://drive.google.com/uc?export=view&id=1slOlWQHWdos4gRAoXqkBtW85YUpJ5AX4",
       "https://drive.google.com/uc?export=view&id=1WUcnbQf33d-OImNnvymH2x042aplC7JJ"]'::jsonb),
    ('maxime_gazzera', date '2026-06-07',
     '["https://drive.google.com/uc?export=view&id=1fnH88NN5npCAoBkmNV_5eNeTCUPUd9qz"]'::jsonb)
)
UPDATE public.bilans b
SET photos = r.new_photos
FROM recovered r
JOIN public.clients c
  ON lower(replace(c.first_name || '_' || c.last_name, ' ', '_')) = r.client_key
WHERE b.client_id = c.id
  AND b.date = r.bilan_date
  AND (b.photos IS NULL OR b.photos = '[]'::jsonb);
