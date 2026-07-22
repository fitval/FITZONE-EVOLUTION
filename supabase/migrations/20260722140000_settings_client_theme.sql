-- Thème (clair/sombre) de l'app client, défini par le coach depuis le dashboard
alter table public.settings add column if not exists client_theme text default 'light';
