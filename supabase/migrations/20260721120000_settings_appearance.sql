-- Apparence du dashboard coach : thème clair/sombre + couleur de marque
alter table public.settings add column if not exists theme text default 'light';
alter table public.settings add column if not exists brand_color text default '#c49a2a';
