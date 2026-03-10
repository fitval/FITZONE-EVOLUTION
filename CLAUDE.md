# FITZONE EVOLUTION

> **IMPORTANT** : Lis aussi `MEMORY.md` au début de chaque session pour connaître l'état actuel du projet et les prochaines étapes.

## Projet
Application SaaS de coaching sportif et nutritionnel.
- **Dashboard coach** : interface web PC pour gérer clients, programmes, nutrition, etc.
- **App mobile client** (à venir) : accès client aux programmes, nutrition, questionnaires.
- **Objectif final** : plateforme complète coach + app client sur les stores (iOS/Android).
- **Fondateur** : coach sportif solo qui développe avec Claude.

## Architecture actuelle
- **Frontend** : HTML/CSS/JavaScript vanilla (pas de framework), fichiers monolithiques (inline CSS + JS)
- **Backend/Auth** : Supabase (Auth + PostgreSQL)
- **Déploiement** : GitHub Pages depuis repo `fitval/FITZONE-EVOLUTION`, dossier `fitzone_deploy/`
- **Pas de domaine** personnalisé pour le moment
- **Pas de build step** : les fichiers HTML sont servis directement

## Fichiers principaux
- `fitzone_deploy/index.html` — Redirect vers login
- `fitzone_deploy/login.html` — Auth coach (Supabase Auth)
- `fitzone_deploy/dashboard.html` — Dashboard coach (fichier monolithique ~2200 lignes, ~185 KB)
- `fitzone_deploy/questionnaire.html` — Formulaire client (accès par token, ~53 KB)

## Supabase
- **URL** : `https://wsrykmutyhjxdnhnyexl.supabase.co`
- **Tables** : `coaches`, `clients`, `questionnaires`, `plans`
- **Auth** : email/password pour les coachs
- **Client JS** :
```javascript
const SUPA = 'https://wsrykmutyhjxdnhnyexl.supabase.co';
const KEY = 'sb_publishable_e_FCHR17eNikXRpUKG6jmA_d4WbSai3';
const { createClient } = supabase;
const db = createClient(SUPA, KEY);
```

## Stockage hybride (migration en cours)
### Dans Supabase (migré)
- Auth (session, login, register)
- Coaches (profil coach lié à user_id)
- Clients (CRUD complet, filtres par statut/tags)
- Questionnaires (soumis par les clients via token)
- Plans nutrition macros (partiellement)

### Encore en localStorage (à migrer vers Supabase)
| Clé localStorage | Contenu |
|---|---|
| `fz_exos` | Bibliothèque d'exercices |
| `fz_progs` | Programmes d'entraînement |
| `fz_seances` | Séances d'entraînement |
| `fz_alims` | Base de données aliments |
| `fz_repas` | Templates de repas |
| `fz_plans` | Plans nutrition complets |
| `fz_modules` | Modules de formation |
| `fz_team` | Équipe coaching |
| `fz_settings` | Préférences utilisateur |
| `road_<id>` | Roadmap 52 semaines par client |
| `pfRecent` | Aliments récents (plan builder) |

## Modules du dashboard
1. **Overview** — Stats, actions rapides
2. **Clients** — Gestion clients, questionnaires, détail client (nutrition calc, roadmap)
3. **Nutrition** — Plans alimentaires (macros + complets), base aliments, repas/recettes
4. **Training** — Programmes, séances, bibliothèque exercices (séries individuelles, supersets)
5. **Learning** — Modules de formation avec chapitres et vidéos YouTube
6. **Équipe** — Gestion staff coaching (rôles, couleurs)
7. **Settings** — Profil, paramètres par défaut, export/import

## Conventions de code
- Tout le code est inline dans chaque fichier HTML (CSS + JS)
- Interface en **français** (pas d'i18n)
- Design **clair** avec accent **doré/gold** (`#c49a2a` / `#e8b84a`), fond `#f0ede8`
- Font : system fonts (`-apple-system, BlinkMacSystemFont, 'SF Pro Display'`)
- Icônes : Font Awesome (via CDN)
- Variables CSS dans `:root`

## Conventions de nommage (JS)
- Classes CSS courtes : `.sb`, `.fi`, `.fg`, `.fl`, `.btn`, `.cp`, etc.
- Fonctions courtes : `lsGet`, `lsSave`, `txt`, `openM`, `closeM`
- State global : variables `let` en haut du script
- ~152 fonctions JS dans dashboard.html

## Règles OBLIGATOIRES
1. **Ne jamais casser la compatibilité** avec les données existantes (localStorage ET Supabase)
2. **Toujours tester** que le fichier HTML est valide (balises fermées, JS sans erreur)
3. **Garder le design cohérent** avec le thème existant (clair/gold)
4. **Pusher sur GitHub** pour que les changements soient visibles en production
5. **Un seul dev** (le fondateur/coach) — garder le code simple et lisible
6. **Mettre à jour MEMORY.md** après chaque changement significatif (nouvelle feature, bug fix, décision technique)

## Git
- Repo : `github.com/fitval/FITZONE-EVOLUTION`
- Branche principale : `main`
- Branches Claude : `claude/<feature>-session_<id>`
- Toujours merger dans `main` une fois la feature validée
