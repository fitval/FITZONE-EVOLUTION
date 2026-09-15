-- Affichage par client dans l'app : ligne « Mon parcours » (%) et tchat coach.
-- true par défaut → aucun changement pour les clients existants.
alter table public.clients add column if not exists show_progress boolean not null default true;
alter table public.clients add column if not exists show_chat boolean not null default true;
