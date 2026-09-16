-- Suppression de la table de test créée par 20260913120000_test_mcp.sql (vérification accès MCP).
-- Pas de cascade : l'instruction échoue si un objet dépend encore de la table.
drop table if exists public.test_mcp;
