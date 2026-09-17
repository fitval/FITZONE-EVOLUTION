# FITZONE EVOLUTION

> **IMPORTANT** : Lis aussi `MEMORY.md` au début de chaque session pour connaître l'état actuel du projet et les prochaines étapes.

## Projet
Application SaaS de coaching sportif et nutritionnel.
- **Dashboard coach** : interface web PC pour gérer clients, programmes, nutrition, etc.
- **App mobile client** (à venir) : accès client aux programmes, nutrition, questionnaires.
- **Objectif final** : plateforme complète coach + app client sur les stores (iOS/Android).
- **Fondateur** : coach sportif solo qui développe avec Claude.

## Langue
- Réponses en **français**, du début à la fin de la session, y compris les comptes rendus après une commande,
  un commit ou un déploiement. Seuls restent tels quels le code, les commandes, les noms de fichiers et les
  messages d'erreur cités.

## Sécurité — règles non négociables
- Base Supabase **en production**, avec de vraies clientes (adresses, téléphones, bilans de santé). Toute
  modification : ce qu'elle change, un test, puis la suivante. Le SQL collé dans l'éditeur Supabase s'écrit
  **une instruction par ligne**.
- Le dépôt est **public** (GitHub Pages). Aucun secret dans le code, les commentaires, les commits ou `MEMORY.md`.
  Seule la clé `sb_publishable_` y a sa place : elle est publique par conception. Les clés legacy (`anon`,
  `service_role`) sont désactivées depuis le 17/09/2026.
- **Aucune faiblesse non corrigée ne s'écrit dans le dépôt** (ni `MEMORY.md`, ni commentaire, ni message de
  commit). Les points ouverts vivent dans une note privée, hors dépôt. Dans le dépôt, on écrit les règles à suivre.
- Ne jamais faire remonter de données de clientes dans une conversation : des nombres et des structures, pas des lignes.
- **Règles RLS** : jamais de `USING (true)` ni d'accès `anon` à des données de clientes. Toute nouvelle règle
  s'appuie sur `get_my_client_id()`, `get_my_coach_id()` ou `is_admin()`. Toute modification passe par une
  **migration** dans `supabase/migrations/`, jamais à la main sans trace. État de référence :
  `supabase/migrations/20260917120000_rls_etat_reel_corrections_manuelles.sql`. Les anciens scripts de
  `supabase/` marqués « NE JAMAIS REJOUER » ne se recollent jamais.
- **Fonctions Edge** : chaque fonction vérifie elle-même son appelant avec `supabase/functions/_shared/securite.ts`
  (`exigerCoach`, `exigerCompte`) et accède à la base par `clientAdmin()` (clé secrète), jamais par
  `SUPABASE_SERVICE_ROLE_KEY`. Exceptions voulues, sans contrôle d'appelant : `send-email` (restreinte hors
  session coach), `submit-questionnaire` (jeton de fiche), `notify-webhook` (publique). Toute nouvelle fonction
  vérifie son appelant.
- **Avant tout déploiement de fonction** : relever `npx supabase functions list`, redéployer chaque fonction
  **sous son adresse réelle** et **avec son réglage `verify_jwt` actuel**. Jamais `--prune`.
- **Comptes** : les inscriptions publiques Supabase sont désactivées. Les comptes se créent uniquement par les
  fonctions `create-client-account` et `create-coach-account`.

## Ce qu'il faut savoir sur ce projet
- Site statique (HTML) publié par GitHub Pages · base, comptes et fonctions : Supabase.
- Stripe et Whop sont utilisés **hors de l'app** : la table `payments` est saisie à la main dans le dashboard
  (aucune intégration, aucun webhook entrant).
- Les clientes se connectent par email et mot de passe (`client-login.html`).
- `recruitment.html` est **public** : rempli sans compte.
- Le dépôt ne contient qu'une partie du schéma (les tables de base ne sont dans aucune migration) : **la base est
  la vérité du schéma**, pas le dépôt.

## Architecture actuelle
- **Frontend** : HTML/CSS/JavaScript vanilla (pas de framework), fichiers monolithiques (inline CSS + JS)
- **Backend/Auth** : Supabase (Auth + PostgreSQL)
- **Déploiement** : GitHub Pages depuis repo `fitval/FITZONE-EVOLUTION`, dossier `fitzone_deploy/`
- **Pas de domaine** personnalisé pour le moment
- **Pas de build step** : les fichiers HTML sont servis directement

## Fichiers principaux
- `fitzone_deploy/index.html` — Redirect vers login
- `fitzone_deploy/login.html` — Auth coach (Supabase Auth)
- `fitzone_deploy/dashboard.html` — Dashboard coach (fichier monolithique, ~15 250 lignes au 17/09/2026)
- `fitzone_deploy/questionnaire.html` — Contrat à signer et questionnaire d'intégration (lien avec jeton, cliente connectée)
- `fitzone_deploy/client.html` — App cliente (connexion par compte via `client-login.html`)

## Supabase
- **URL** : `https://wsrykmutyhjxdnhnyexl.supabase.co`
- **Tables** : une quarantaine (fiches, contrats, paiements, journaux, programmes, plans…) — la base fait foi
- **Auth** : email/mot de passe pour les coachs et les clientes ; inscriptions publiques désactivées
- **Client JS** :
```javascript
const SUPA = 'https://wsrykmutyhjxdnhnyexl.supabase.co';
const KEY = 'sb_publishable_e_FCHR17eNikXRpUKG6jmA_d4WbSai3';
const { createClient } = supabase;
const db = createClient(SUPA, KEY);
```

## Données et stockage
- **Supabase est la référence** pour toutes les données, dont les fiches clientes (identité, contact), qui ne
  passent jamais par le navigateur.
- Le dashboard garde **des copies en cache dans le `localStorage` du navigateur du coach**, y compris des données
  liées aux clientes : `daily_<id>` (journaux), `bilans_<id>`, `trainlog_<id>`, `road_<id>` / `road_obj_<id>`,
  `fz_plans`, `fz_progs`, ainsi que `fz_exos`, `fz_seances`, `fz_alims`, `fz_repas`, `fz_modules`, `fz_team`,
  `fz_settings`, `fz_finance`, `fz_commissions`. Ce navigateur contient donc des données sensibles.
- `client.html` n'y garde que des préférences d'affichage.

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
