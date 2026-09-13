-- Table de test (vérification accès MCP / migrations)
create table if not exists public.test_mcp (id bigint generated always as identity primary key);
alter table public.test_mcp enable row level security;
