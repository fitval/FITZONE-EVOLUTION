-- Couleur de marque de l'app client, définie par le coach depuis le dashboard
alter table public.settings add column if not exists client_brand_color text default '#c49a2a';
