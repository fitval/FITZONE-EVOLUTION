# FITZONE EVOLUTION

## Projet
Application de coaching sportif et nutritionnel.
- **Dashboard coach** : interface web PC pour gérer clients, programmes, nutrition, etc.
- **App mobile client** (à venir) : accès client aux programmes, nutrition, questionnaires.
- **Objectif** : déploiement sur les stores (iOS/Android) à terme.

## Architecture actuelle
- **Frontend** : HTML/CSS/JavaScript vanilla (pas de framework), fichiers monolithiques (inline CSS + JS)
- **Backend/Auth** : Supabase (Auth + PostgreSQL)
- **Déploiement** : Netlify (depuis GitHub repo `fitval/FITZONE-EVOLUTION`)
- **Pas de domaine** personnalisé pour le moment

## Fichiers principaux
- `fitzone_deploy/index.html` — Redirect vers login
- `fitzone_deploy/login.html` — Auth coach (Supabase Auth)
- `fitzone_deploy/dashboard.html` — Dashboard coach (fichier monolithique ~2200 lignes)
- `fitzone_deploy/questionnaire.html` — Formulaire client (accès par token)

## Supabase
- **URL** : `https://wsrykmutyhjxdnhnyexl.supabase.co`
- **Tables utilisées** : `coaches`, `clients`, `questionnaires`, `plans`
- **Auth** : email/password pour les coachs

## Stockage hybride (migration en cours)
### Données dans Supabase (migré)
- Auth (session, login, register)
- Coaches (profil coach lié à user_id)
- Clients (CRUD complet, filtres par statut/tags)
- Questionnaires (soumis par les clients via token)
- Plans nutrition macros (partiellement)

### Données encore en localStorage (à migrer)
- Exercices (`fz_exos`)
- Programmes (`fz_progs`)
- Séances (`fz_seances`)
- Aliments (`fz_alims`)
- Repas (`fz_repas`)
- Plans complets (`fz_plans`)
- Modules de formation (`fz_modules`)
- Equipe (`fz_team`)
- Roadmap client (`road_<id>`)
- Settings (`fz_settings`)
- Récents plan builder (`pfRecent`)

## Conventions de code
- Tout le code est inline dans chaque fichier HTML (CSS + JS)
- Interface en **français**
- Design **clair** avec accent **doré/gold** (`#c49a2a` / `#e8b84a`), fond `#f0ede8`
- Font : system fonts (`-apple-system, BlinkMacSystemFont, 'SF Pro Display'`)
- Icones : Font Awesome (via CDN)
- Variables CSS dans `:root` (thème cohérent entre toutes les pages)

## Conventions de nommage (JS)
- Classes CSS courtes/minifiées : `.sb`, `.fi`, `.fg`, `.fl`, `.btn`, `.cp`, etc.
- Fonctions courtes : `lsGet`, `lsSave`, `txt`, `openM`, `closeM`
- State global : variables `let` en haut du script

## Supabase client
```javascript
const SUPA = 'https://wsrykmutyhjxdnhnyexl.supabase.co';
const KEY = 'sb_publishable_e_FCHR17eNikXRpUKG6jmA_d4WbSai3';
const { createClient } = supabase;
const db = createClient(SUPA, KEY);
```

## Regles importantes
- Ne jamais casser la compatibilite avec les donnees existantes (localStorage ET Supabase)
- Toujours tester que le fichier HTML est valide (balises fermees, JS sans erreur)
- Garder le design coherent avec le theme existant (clair/gold)
- Les modifications doivent etre pushees sur GitHub pour etre visibles en production
- Un seul dev (le fondateur/coach)

## Git
- Repo : `github.com/fitval/FITZONE-EVOLUTION`
- Branche principale : `main`
- Branches Claude : `claude/<feature>-session_<id>`
