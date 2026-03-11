# MEMORY — FITZONE EVOLUTION

> Ce fichier est la mémoire vivante du projet. Claude doit le lire au début de chaque session et le mettre à jour après chaque changement significatif.

## État actuel du projet
**Dernière mise à jour** : 2026-03-10 (migration Supabase)

### Ce qui fonctionne (en production)
- [x] Page de login/register coach (Supabase Auth)
- [x] Dashboard coach avec navigation sidebar
- [x] Gestion clients complète (CRUD, filtres, tags, statuts)
- [x] Questionnaire client via token (lien unique par client)
- [x] Calculateur nutrition (Harris-Benedict, TDEE, macros)
- [x] Plans nutrition macros (sauvegarde Supabase)
- [x] Plan builder complet (jours, repas, aliments, drag-drop)
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
- [x] Notification 🔔 avec badge pour bilans non lus
- [x] Page Bilans hebdo (listing tous bilans de tous clients)

### Ce qui reste à faire (prochaines priorités)
- [x] **Migration localStorage → Supabase** : exercices, programmes, aliments, repas, plans complets, modules, équipe, settings, roadmaps, daily logs, train logs, bilans (code prêt, **il faut exécuter le SQL dans Supabase**)
- [ ] **App mobile client** : permettre aux clients d'accéder à leurs programmes et plans nutrition
- [ ] **Amélioration UX** : responsive, animations, feedback visuel
- [ ] **Multi-coach** : isolation des données par coach (RLS Supabase)
- [ ] **Domaine personnalisé** : configurer un nom de domaine propre
- [ ] **PWA** : transformer le dashboard en Progressive Web App

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
- **Notification 🔔** : badge rouge compteur bilans non lus, lié à la page bilans-all
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
- **⚠️ ACTION REQUISE** : exécuter `supabase/migration.sql` dans le SQL Editor de Supabase

## Bugs connus
- Aucun bug critique identifié pour le moment

## Notes pour Claude
- Le fondateur est un **coach sportif**, pas un développeur. Explique les choix techniques simplement.
- Il travaille **seul** sur le projet. Pas de code review, pas de CI/CD.
- Le projet est en **français**. Toute l'interface et les messages sont en français.
- **Priorité** : features fonctionnelles > perfection du code. Le but est d'avoir un outil utilisable rapidement.
- Quand tu fais des modifications, **teste mentalement** que rien n'est cassé (pas de tests automatisés).
- **Toujours demander** avant de refactorer du code existant qui fonctionne.
