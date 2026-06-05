-- Assure la lecture de la colonne muscle_group_images côté client (auth ET anon legacy).
-- Sans risque : si un GRANT SELECT au niveau table existe déjà, ce grant de colonne
-- est simplement redondant. S'il existe des grants au niveau colonne (ce qui exclurait
-- une colonne nouvellement ajoutée), ceci débloque sa lecture.
GRANT SELECT (muscle_group_images) ON public.settings TO anon, authenticated;
