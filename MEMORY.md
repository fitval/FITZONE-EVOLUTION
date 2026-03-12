# MEMORY — FITZONE EVOLUTION

> Ce fichier est la mémoire vivante du projet. Claude doit le lire au début de chaque session et le mettre à jour après chaque changement significatif.

## État actuel du projet
**Dernière mise à jour** : 2026-03-12 (Edge Functions IA + éditeur plans + swaps client)

### Ce qui fonctionne (en production)
- [x] Page de login/register coach (Supabase Auth)
- [x] Dashboard coach avec navigation sidebar
- [x] Gestion clients complète (CRUD, filtres, tags, statuts)
- [x] Questionnaire client via token (lien unique par client)
- [x] Calculateur nutrition (Harris-Benedict, TDEE, macros)
- [x] Plans nutrition macros (sauvegarde Supabase)
- [x] Plan builder complet (jours, repas, aliments, drag-drop) — overlay plein écran, utilisable depuis n'importe quelle page
- [x] Création inline d'aliments et repas dans le plan builder
- [x] Programme builder (jours, sections warmup/workout/cooldown)
- [x] Séries individuelles par exercice (reps, rest, RIR, tempo par série)
- [x] Support supersets
- [x] Séances d'entraînement
- [x] Bibliothèque exercices (avec vidéo YouTube)
- [x] Base de données aliments (avec source macro : protéines/glucides/lipides)
- [x] Équivalences alimentaires dans le plan builder (swap automatique avec quantités ajustées)
- [x] Exercices de remplacement (alternatives configurables par exercice, swap en séance)
- [x] Capture vidéo en séance (filmer ou importer, stockage IndexedDB)
- [x] Templates repas/recettes
- [x] Modules de formation (chapitres + vidéos)
- [x] Gestion équipe coaching
- [x] Roadmap 52 semaines par client (colonne unique texte libre pour apports)
- [x] Thème clair avec accents gold + logo SVG FE
- [x] Overview avec stats
- [x] Mention "poids cru" sur tous les formulaires aliments
- [x] Drag & drop réordonnement aliments dans repas + repas dans plan
- [x] Détail plan alimentaire dépliable (jours → repas → aliments avec macros)
- [x] Import base de données aliments (CSV/TSV/JSON avec détection auto colonnes)
- [x] Détail complet repas/recettes (ingrédients, instructions, macros)
- [x] Learning refactoré : grille modules → liste chapitres → page vidéo YouTube + description + PDF
- [x] Section Progression client (graphiques SVG, métriques quotidiennes, stats)
- [x] Section Training client (blocs cycles colorés violet/rouge/jaune/vert)
- [x] Section Bilan client (historique, photos, contenu, réponses)
- [x] Section Galerie client (grille photos issues des bilans)
- [x] Notification avec badge pour bilans non lus
- [x] Page Bilans hebdo (listing tous bilans de tous clients)
- [x] App mobile client (`client.html`) avec 4 onglets : Programme, Nutrition, Bilan, Progression
- [x] Bouton "App" dans le dashboard pour copier le lien client
- [x] **Génération plan alimentaire IA** (Edge Function `generate-meal-plan`, Claude Sonnet, streaming)
- [x] **Import recettes par screenshot** (Edge Function `analyze-recipe`, Claude Vision)
- [x] **Éditeur inline plan alimentaire** dans la fiche client (modifier quantités, ajouter/supprimer aliments, sauvegarder vers Supabase)
- [x] **Swap exercices dans preview** app client (bouton ⇄ avant de lancer la séance)
- [x] **Équivalences alimentaires app client** (bouton ⇄ par aliment, calcul iso-calorique, filtre par même source macro)

### Ce qui reste à faire (prochaines priorités)
- [ ] **Amélioration UX** : responsive, animations, feedback visuel
- [ ] **Multi-coach** : isolation des données par coach (RLS Supabase)
- [ ] **Domaine personnalisé** : configurer un nom de domaine propre
- [ ] **PWA** : transformer le dashboard en Progressive Web App

## Architecture technique

### Supabase Edge Functions
- **`generate-meal-plan`** : génère un plan alimentaire 7 jours via Claude Sonnet (streaming), déployée avec `--no-verify-jwt`
- **`analyze-recipe`** : analyse screenshot de recette via Claude Vision, déployée avec `--no-verify-jwt`
- **Secret** : `ANTHROPIC_API_KEY` configuré sur Supabase
- **Clé publishable** : `sb_publishable_...` (pas un JWT standard → `--no-verify-jwt` obligatoire)
- **Project ref** : `wsrykmutyhjxdnhnyexl`

### Points techniques importants
- Le plan builder (`planBuilderWrap`) est un overlay `position:fixed` z-index 9000, sorti de `page-nut-plans`, utilisable depuis n'importe où (fiche client, page plans)
- `pfFromClient` flag : quand on ouvre le builder depuis la fiche client, `closePlanBuilder()` revient à la fiche client au lieu de la page Plans
- `editClientPlan()` charge le plan directement depuis Supabase (évite les problèmes de matching ID bigint entre cache local et Supabase)
- `saveClientPlanEdit()` utilise `upsert` avec `coach_id` (compatible RLS), pas `update`
- Variable globale = `allClients` (PAS `clients`)
- `mealItems(meal)` dans client.html : retourne `meal.items || meal.alims || []` (compatibilité plans manuels vs IA)
- App client charge `coachAlims` (base aliments du coach) pour les équivalences alimentaires

## Décisions techniques prises

| Date | Décision | Raison |
|------|----------|--------|
| 2026-03-09 | Supabase pour auth + clients | Besoin de persistance cloud, multi-device |
| 2026-03-09 | Pas de framework JS | Le fondateur est coach, pas dev — garder simple |
| 2026-03-09 | Fichiers monolithiques HTML | Simplicité de déploiement (GitHub Pages, pas de build) |
| 2026-03-10 | Séries individuelles par exercice | Besoin coaching réel : chaque série peut avoir des paramètres différents |
| 2026-03-10 | Création inline aliments/repas | UX : ne pas quitter le plan builder pour créer un aliment |
| 2026-03-10 | Source macro par aliment | Permet le calcul d'équivalences automatiques |
| 2026-03-10 | Équivalences alimentaires | Client peut swapper un aliment par un équivalent de même source macro |
| 2026-03-10 | Exercices de remplacement | Coach configure des alternatives, client pourra swapper dans l'app |
| 2026-03-10 | Vidéo séance via IndexedDB | localStorage trop limité (5MB), IndexedDB pour stocker les blobs vidéo |
| 2026-03-10 | CLAUDE.md + MEMORY.md | Continuité entre sessions Claude |
| 2026-03-10 | Import aliments multi-format | Permettre import rapide de bases existantes (CSV/TSV/JSON) |
| 2026-03-10 | Learning 3 niveaux | UX modulaire : modules → chapitres → vidéo individuelle |
| 2026-03-10 | Bilans client en base64 | Photos stockées en base64 dans localStorage (bilans_<id>) |
| 2026-03-10 | Progression SVG charts | Graphiques légers sans dépendance externe |
| 2026-03-10 | Migration localStorage → Supabase | Persistance cloud, multi-device, prépare app mobile |
| 2026-03-10 | Double-write (Supabase + localStorage) | Fallback offline, pas de perte de données si Supabase down |
| 2026-03-10 | JSONB pour données complexes | Minimise le nombre de tables, garde la simplicité |
| 2026-03-11 | App client = page web séparée | Même pattern que questionnaire (token URL), pas de framework |
| 2026-03-11 | Bottom tab bar pour l'app client | Navigation mobile native-like (4 onglets) |
| 2026-03-11 | Resize photos avant base64 | Canvas max 1200px + JPEG 0.7 pour limiter la taille |
| 2026-03-12 | Edge Functions avec --no-verify-jwt | Clé publishable pas un JWT → vérification JWT impossible |
| 2026-03-12 | Plan builder en overlay fixed | Permet d'ouvrir le builder depuis n'importe où (fiche client, page plans) |
| 2026-03-12 | Éditeur inline plans dans fiche client | UX : modifier un plan sans quitter la fiche client |
| 2026-03-12 | Upsert pour sauvegarder plans modifiés | Compatible RLS (coach_id requis), update seul échouait |
| 2026-03-12 | Swap aliments filtré par source macro | Client ne peut remplacer que par un aliment de même source (glucides→glucides) |

## Historique des sessions

### Session 2026-03-09
- Création du système d'auth coach (login.html, protection dashboard)
- Migration clients vers Supabase
- Questionnaire client avec système de tokens

### Session 2026-03-10
- Ajout séries individuelles par exercice (programme builder + séances)
- Ajout création inline d'aliments et repas dans le plan builder
- Création du CLAUDE.md et MEMORY.md
- **Source macro** par aliment (protéines/glucides/lipides) dans modal + inline form
- **Équivalences alimentaires** : bouton ⇄ par aliment dans le plan builder, dropdown avec alternatives de même source et quantités auto-ajustées
- **Exercices de remplacement** : champ multi-select dans la fiche exercice, bouton swap dans programme builder et séances
- **Capture vidéo en séance** : bouton filmer (caméra) + importer (fichier), stockage IndexedDB, lecture inline
- **Poids cru** mentionné dans les formulaires aliments (modal, inline, titre input)
- **Drag & drop** : réordonnement aliments intra-repas + repas intra-plan
- **Détail plan dépliable** : clic sur un plan affiche tous jours/repas/aliments avec macros
- **Import aliments** : CSV/TSV/JSON, détection auto des colonnes (regex patterns)
- **Détail recettes** : ingrédients, instructions, totaux macros au clic
- **Learning refactoré** : 3 vues (modules grille → chapitres liste → vidéo page avec embed YouTube + description + lien PDF)
- **Roadmap** : colonne unique texte libre remplaçant les 3 colonnes haut/moy/bas (rétrocompatible)
- **Logo SVG FE** dans la sidebar
- **Notification** : badge rouge compteur bilans non lus, lié à la page bilans-all
- **Sections fiche client** : Progression (graphique SVG + métriques quotidiennes), Training (blocs cycles colorés), Bilan (historique + photos base64), Galerie (grille photos)
- **Page Bilans hebdo** : listing global tous bilans de tous clients, marquage lu/non-lu

### Session 2026-03-10 (migration Supabase)
- **Migration localStorage → Supabase complète** : toutes les données sont maintenant synchronisées avec Supabase
- Nouvelles tables Supabase : `exercises`, `programs`, `seances`, `aliments`, `repas`, `plans_full`, `modules`, `team`, `settings`, `roadmaps`, `daily_logs`, `train_logs`, `bilans`
- **Couche d'abstraction DB** : fonctions `dbLoad()`, `dbSave()`, `dbDelete()`, `dbLoadClientData()`
- **Migration automatique** : au premier chargement, les données localStorage sont uploadées vers Supabase (flag `fz_migrated_v1`)
- **Double-write** : chaque sauvegarde écrit dans Supabase ET localStorage (fallback)
- **Chargement hybride** : données globales chargées au démarrage depuis Supabase, données client chargées à la demande (lazy)
- **RLS activé** sur toutes les tables (politique "Allow all for authenticated" — à renforcer plus tard)

### Session 2026-03-11 (app mobile client)
- **Fix dbSave mapping** : correction camelCase → snake_case pour programmes, séances, plans (clientId→client_id, etc.)
- **App mobile client** (`client.html` ~750 lignes) : page web complète pour les clients
  - Auth par token URL (même pattern que questionnaire)
  - **Onglet Programme** : liste programmes, détail avec jours/exercices/sets, vidéo YouTube, supersets, alternatives
  - **Onglet Nutrition** : plans macros et complets, détail jours/repas/aliments avec calcul macros
  - **Onglet Bilan** : historique + formulaire (poids, énergie, sommeil, adhérence, photos avec resize canvas)
  - **Onglet Progression** : suivi quotidien (8 métriques), graphique SVG, historique, sliders
  - Design mobile-first, bottom tab bar, même thème gold/clair
- **Bouton "App"** dans le dashboard : visible dans la fiche client pour les clients actifs

### Session 2026-03-12 (Edge Functions IA + éditeur plans + swaps)
- **Déploiement Edge Functions Supabase** :
  - `generate-meal-plan` et `analyze-recipe` déployées avec `--no-verify-jwt`
  - Secret `ANTHROPIC_API_KEY` configuré
  - Fix erreur 401 (clé publishable pas un JWT → désactivation vérification JWT)
- **Fix liaison données plan IA → app client** : `meal.items` vs `meal.alims` — ajout `mealItems()` helper
- **Icône nutrition app client** : remplacée par cuisse de poulet (drumstick SVG)
- **Éditeur inline plan alimentaire dans fiche client** :
  - Boutons ✏️ (modifier) et ✕ (supprimer) sur chaque plan
  - Éditeur directement dans `planDisp` (pas de navigation vers page Plans)
  - Onglets jours, modification quantités, ajout/suppression aliments depuis base coach
  - Sauvegarde via `upsert` avec `coach_id` (compatible RLS)
  - Recalcul automatique macros moyennes
- **Plan builder en overlay** : `planBuilderWrap` sorti de `page-nut-plans`, position:fixed z-index 9000
- **Bouton "Modifier" après génération IA** : sauvegarde + ouvre l'éditeur
- **Swap exercices en preview** (app client) : bouton ⇄ sur chaque exercice avant de lancer la séance
- **Équivalences alimentaires** (app client) :
  - Bouton ⇄ sur chaque aliment dans le plan nutrition
  - Popup plein écran avec recherche
  - Calcul automatique quantité iso-calorique (ex: 80g riz → 93g pâtes)
  - **Filtré strictement par même source macro** (glucides→glucides uniquement)
  - Chargement base aliments coach (`coachAlims`) dans l'app client
- **Installation `gh` CLI** et configuration auth GitHub pour push automatique

## Bugs connus
- Aucun bug critique identifié pour le moment

## Notes pour Claude
- Le fondateur est un **coach sportif**, pas un développeur. Explique les choix techniques simplement.
- Il travaille **seul** sur le projet. Pas de code review, pas de CI/CD.
- Le projet est en **français**. Toute l'interface et les messages sont en français.
- **Priorité** : features fonctionnelles > perfection du code. Le but est d'avoir un outil utilisable rapidement.
- Quand tu fais des modifications, **teste mentalement** que rien n'est cassé (pas de tests automatisés).
- **Toujours demander** avant de refactorer du code existant qui fonctionne.
- Variable globale clients = `allClients` (pas `clients`)
- Plans IA utilisent `alims`, pas `items` — utiliser `mealItems()` dans client.html
- Edge Functions nécessitent `--no-verify-jwt` à chaque redéploiement
