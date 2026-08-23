# MEMORY — FITZONE EVOLUTION

> Ce fichier est la mémoire vivante du projet. Claude doit le lire au début de chaque session et le mettre à jour après chaque changement significatif.

## État actuel du projet
**Dernière mise à jour** : 2026-08-20 (deload/phase éphémère sur les programmes + tableau de progression client + RIR à virgule)

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
- [x] App mobile client (`client.html`) avec 4 onglets : Accueil, Entraînement, Nutrition, Apprentissage
- [x] Bouton "App" dans le dashboard pour copier le lien client
- [x] **Génération plan alimentaire IA** (Edge Function `generate-meal-plan`, Claude Sonnet, streaming)
- [x] **Import recettes par screenshot** (Edge Function `analyze-recipe`, Claude Vision)
- [x] **Éditeur inline plan alimentaire** dans la fiche client (modifier quantités, ajouter/supprimer aliments, sauvegarder vers Supabase)
- [x] **Swap exercices dans preview** app client (bouton ⇄ avant de lancer la séance)
- [x] **Équivalences alimentaires app client** (bouton ⇄ par aliment, calcul iso-calorique, filtre par même source macro)
- [x] **Bilan hebdo sur page Accueil** (bulle grisée/dorée selon jour de bilan, cliquable pour remplir)
- [x] **Icônes app client** : Accueil = maison, Nutrition = bol fumant, onglet Bilan retiré de la nav
- [x] **UI nutrition améliorée** (barre macros colorée P/G/L, icônes repas, pastilles source macro, instructions affichées)
- [x] **Notifications webhooks par formulaire de recrutement** : éditeur de webhook liste tous les `recruitment_forms` du coach comme cases à cocher individuelles (clé `recruitment_response:<form_id>`), filtrage côté Edge Function `notify-webhook`
- [x] **Scan code-barres app client (Nutrition)** : lib `html5-qrcode` + lookup OpenFoodFacts (~3M produits), preview macros+micros (sucre/fibres/sat_fat/sel), insert `food_logs` avec colonne JSONB `extra` (migration `food_logs_extra.sql`). Visible coach via les requêtes food_logs existantes (pas de duplication daily_logs)

### Ce qui reste à faire (prochaines priorités)
- [ ] **Amélioration UX** : responsive, animations, feedback visuel
- [ ] **Multi-coach** : isolation des données par coach (RLS Supabase)
- [ ] **Domaine personnalisé** : configurer un nom de domaine propre
- [ ] **PWA** : transformer le dashboard en Progressive Web App

## Architecture technique

### Supabase Edge Functions
- **`generate-meal-plan`** : génère un plan alimentaire via Claude Haiku 4.5 (`claude-haiku-4-5-20251001`), streaming, max_tokens=20000, food_database capée à 200 items, déployée avec `--no-verify-jwt` (sinon erreur 401). Modèle bumpé depuis Sonnet 4 — Haiku passe ~30-60s, sous la limite 150s (sinon erreur 546). **Structure stricte des repas** : recette du coach EN PRIORITÉ, sinon repas simple = 4 briques (protéine + glucide + fibre + lipide) + 1-2 condiments (sauce tomate, crème fraîche, citron…) tous from coach DB ; les épices/herbes sont MENTIONNÉES dans les instructions, pas dans alims (macros négligeables) ; MAX 5 alims par repas. **Matériel cuisine** (`config.equipment`) et **préférences** (`config.preferences`) injectés dans le prompt. **Cibles macros par créneau** calculées server-side (`kcal/mealsPerDay`) + RESCALE FORCÉ post-génération (`a.qte *= perSlotKcal / mealKcal`, borné [0.5×, 2×]) → kcal par créneau identique chaque jour. **Instructions** obligatoires, sans quantités (ni grammes, ni ml même pour les liquides de cuisson) — vérifié 21/21.
- **`generate-training-plan`** : génère un programme d'entraînement via Claude Sonnet (streaming), `--no-verify-jwt`. Méthode coach encodée : `priority_muscles` pilote ordre/volume(6-16 séries/sem)/fréquence/split, repos 90s petits muscles → 180-240s gros polyart borné par durée séance. **Fourchettes de reps** strictement limitées à `"5-8" / "9-12" / "10-15" / "13-16" / "MAX"` (tiret, jamais slash) + durées warmup/cooldown ; 2 fourchettes possibles sur un même exo, la PLUS COURTE en premier (heavy d'abord). **Match flexible des exos** (server + dashboard) : (1) normalisation lowercase + suppression accents + ponctuation → espace ; (2) si pas de match exact normalisé, **match par tokens** avec stopwords filtrés (a/la/le/avec/de/du/des/à…) — les tokens de la BIBLIO doivent tous être présents dans le nom IA, sinon drop ; (3) **renommage automatique** vers le nom exact de la biblio pour que tous les enrichissements (vidéo, équipement, notes, replacements) propagent. Le strict equality d'avant droppait tout. La biblio coach est désormais autoritative sur les enrichments (`m.video||ex.video`, pas l'inverse). **Normalisation reps** vers les 5 fourchettes autorisées par midpoint. Form : modal `mGenTrainPlan`, champ `gtpPriority`. Rendu dashboard : `s.reps==='MAX'` matché en regex `/^max$/i` (insensible à la casse).
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
- **Contrats depuis la fiche client** : bouton 📄 Contrat → `openClientContractsList`. La vue contrat propose « ✏️ Modifier (avenant) » et « 🔄 Remplacer par un autre contrat » → modal `mAddContract` / `openAddContractModal(clientId, 'avenant'|'replace')`. Les deux SUPPRIMENT les contrats non signés existants (+ paiements `pending`) puis recréent un `client_contracts` + `payments`. Les contrats DÉJÀ SIGNÉS ne sont jamais supprimés (avenant = nouveau contrat à côté). Statut repassé à `contract_pending` seulement si le client n'est pas encore actif. Limite connue : un client `active` ne peut pas signer via questionnaire.html (redirigé) — OK pour les clients en attente.
- Math des échéanciers de paiement centralisée dans `_computeSchedule()` (pure, sans DOM), utilisée par `_nfCollectPlanData` (nouveau client) ET `_acCollectPlanData` (avenant). Une seule source pour les 4 plans : one_shot / recurring / downpayment / installments.
- **Photos du questionnaire d'intégration** : questions de type `photo` (custom, q_integration_v2). Uploadées sur Google Drive (Apps Script `DRIVE_UPLOAD_URL`), URLs stockées dans `questionnaires.extra_questions[questionId]` (tableau d'URLs). Affichées sur la fiche client → onglet Questionnaire dans une section dédiée « 📷 Photos du questionnaire » EN HAUT (`_qPhotosSectionHtml` + `_qExtractPhotos`), chaque vignette cliquable (ouvre l'original dans Drive même si l'aperçu inline est bloqué, fallback placeholder 📷). Labels mappés via `_qCustomLabelMap` (chargé depuis settings.q_integration + q_integration_v2.custom dans `openDet`). La section « Questions personnalisées » n'affiche plus les photos (juste un renvoi vers la galerie).
- **Images Google Drive en `<img>`** : OBLIGATOIRE `referrerpolicy="no-referrer"` sinon Google renvoie 403 et l'image est cassée. URL directe via `lh3.googleusercontent.com/d/ID` (`_qDriveDirectUrl`/`driveImgUrl`), fallback `drive.google.com/thumbnail?id=ID&sz=w400` via `onerror`.
- **Chargement questionnaire dans `openDet`** : ne PAS utiliser `.order('submitted_at',{ascending:false}).limit(1)` — Postgres met les NULL en premier (NULLS FIRST en DESC), donc une ligne sans `submitted_at` masque la vraie réponse. On récupère TOUTES les soumissions et on trie en JS (date la plus récente, NULL = plus ancienne). L'erreur de requête est capturée dans `window._qLoadError` et l'état vide distingue « non reçu » vs « réponses introuvables » (statut reçu mais 0 ligne → doublon de fiche probable).
- **Récupération réponses doublon** : bouton « 🔗 Récupérer les réponses » sur l'état vide du questionnaire (`openRecoverQuestionnaire`) → liste TOUTES les réponses lisibles par le coach (`questionnaires` avec `.neq('client_id',fiche actuelle)` ; le RLS limite déjà aux clients du coach / tout si admin) — PAS seulement les fiches au nom identique, car le doublon peut avoir un nom/email différent. Les correspondances nom/email sont badgées « CORRESPOND » et triées en tête. `relinkQuestionnaire` rattache (UPDATE `questionnaires.client_id = fiche actuelle`). Réponses orphelines (ancienne fiche supprimée → cascade) NON récupérables via RLS → fallback : renvoyer le lien pour re-remplir.
- **Recherche bibliothèque exercices** : input `#exoSearchInput` → `exoSearch()` → `_exoSearch` ; `renderExoPage()` filtre `exos` (nom/muscle/equip) en normalisant (lowercase + suppression accents).
- **Portions cuisinées par repas (client.html)** : sélecteur −/+ sur chaque repas du plan alimentaire (`renderPlanDetail`). Multiplicateur par 0.5, borné [0.5 ; 10], persisté dans `localStorage.fz_mealPortions[planRefId][dayIdx][mealIdx]`. Affecte : quantités/kcal des aliments affichés, totaux du repas, macros journalières (`calcDayMacros` accepte planRefId+dayIdx), moyenne du plan, et liste de courses (`clBuildGrocery` multiplie aussi).
- **Builder plan alimentaire** (`pfRenderMeals`) : renommage de repas via double-clic OU bouton ✎ (déclenche `pfRenameMeal`), et zone textarea d'instructions par repas (`pfUpdInstr`) qui se persiste dans `r.instructions`. Les instructions générées par l'IA sont éditables ici, et un plan créé manuellement peut avoir ses propres instructions. ⚠️ Les instructions ne doivent PAS contenir de quantités (gérées par les aliments + scaling serveur).
- App client charge `coachAlims` (base aliments du coach) pour les équivalences alimentaires
- `getBilanCountdown()` retourne `{days, label, isBilanDay, bilanDoneThisWeek}` — utilisé pour la bulle bilan sur Home
- Onglet Bilan retiré de la tab-bar mais `tabBilan` section HTML reste (accessible via `switchTab('Bilan')` depuis Home)

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
| 2026-03-12 | Bilan retiré de la nav, déplacé sur Home | Simplifier la nav à 4 onglets, bilan accessible via bulle contextuelle |
| 2026-03-12 | Refonte UI nutrition app client | Plan detail plus visuel : barre macros, icônes repas, pastilles source |

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
- **Icône nutrition app client** : remplacée par bol fumant (SVG tasse + vapeur)
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

### Session 2026-03-12 (UX app client)
- **Retrait onglet Bilan** de la barre de navigation (4 onglets : Accueil, Entraînement, Nutrition, Apprentissage)
- **Bulle bilan hebdomadaire sur la page Accueil** :
  - Dorée + cliquable si c'est le jour du bilan (ouvre le formulaire bilan)
  - Grisée avec compte à rebours si ce n'est pas le jour
  - Atténuée avec ✓ si déjà envoyé cette semaine
  - Logique via `getBilanCountdown()` retournant `isBilanDay` et `bilanDoneThisWeek`
- **Icône Accueil** : remplacée par maison SVG (était un cercle)
- **Icône Nutrition** : remplacée par bol fumant SVG (était une clé/drumstick)
- **Refonte UI détail plan nutrition** (`renderPlanDetail()`) :
  - Calories en grand au centre avec barre macros colorée (bleu P, or G, orange L)
  - Pastilles colorées par macro pour le résumé du jour
  - Icônes émoji par repas (🌅 petit-déj, 🍽️ déjeuner, 🌙 dîner, 🍎 goûter)
  - Point coloré par source macro sur chaque aliment
  - Affichage des instructions de préparation quand disponibles
  - En-tête repas avec fond gradient gold subtil
- **`switchTab('Bilan')`** fonctionne toujours (appelé depuis la bulle Home), highlight sur btnHome

### Session 2026-03-12 (dashboard fixes + sync training)
- **Couleur courbe progression** : changée de bleu (#3b82f6) à or (#c49a2a)
- **Bug program builder** : overlay gris bloquait l'ajout du 2e exercice. Fix : `position:relative` sur le parent du thumbnail vidéo + condition `e.video&&ytId(e.video)` + `onerror` sur img
- **Exercices sans vidéo** : possibilité d'ajouter des exercices même si la vidéo YouTube n'est pas valide
- **Sync training client→dashboard** : refactoré les 3 onglets (Training, Progression, Bilans) pour toujours charger depuis Supabase
- **Bug critique séries vides** : `onchange` sur mobile ne se déclenche qu'au blur → si le client tape ses valeurs et appuie "Terminer" directement, les données n'étaient pas capturées (`sets: []`). Fix : passage à `oninput` + filtre élargi dans `finalizeWorkout()`
- **Tableau progression style tableur** : colonnes REPS/LOAD/RIR/R×L/NOTE par date de séance, vert/rouge pour les améliorations, ligne TOTAL avec nb séries + volume
- **Console log debug** : `[WORKOUT SAVE]` dans `finalizeWorkout()` pour tracer les données sauvegardées
- **Champ comment** sauvegardé dans `train_logs` (était ignoré avant)

### Session 2026-05-31 (fix bilan « pas reçu côté coach »)
- **Symptôme** : bilans hebdo de certains clients récents (Clément, Béatrice) jamais reçus côté coach (ni notif Discord, ni données), alors que d'autres clients passaient bien.
- **Diagnostic (écarté un par un, preuves en base)** : coach_id OK (identique à des clients qui marchent), RLS OK (`auth_bilans_client_insert` = même policy que `daily_logs`/`train_logs` où ils écrivent sans souci), identité auth OK (linkage clients.user_id ↔ auth.users correct, pas de doublon), aucune régression de code (aucun commit sur `submitBilan`). Tous les bilans récents en base sont bien soumis par les clients (`reponses` rempli).
- **Vraie cause** : `submitBilan()` uploadait les photos sur Google Drive **avant** l'insert, dans un `try` **sans `catch`** et **sans timeout**. Un upload Drive figé (Apps Script flaky) bloquait toute la soumission ; le `finally` ne tournait jamais → `_bilanSubmitting` restait à `true` → tous les clics « Envoyer » suivants ignorés en silence. Touche les sessions client coincées (par instance, d'où « seulement certains clients »).
- **Fix** (`client.html`, commit `7a094d0`) : insert/update du bilan **en premier** (le bilan + la notif Discord ne dépendent plus des photos) → upload Drive **en arrière-plan** puis update de la ligne (non bloquant) → **timeout 30s** (AbortController) sur le fetch Drive → `catch` qui affiche l'erreur → gamification isolée dans son propre try.
- **À faire** : demander à Clément/Béatrice de **recharger l'app** (vider le cache) puis re-soumettre un bilan ; vérifier la réception + la notif Discord « Bilan Hebdo ».
- **Webhook Discord** : config coach OK (settings.notifications contient bien `bilan_submitted` → webhook « Bilan Hebdo » activé). `notify-webhook` se déclenche côté client après insert réussi.

### Session 2026-06-07 (fix photos de bilan invisibles côté coach)
- **Symptôme** : depuis le fix du 31/05, les photos uploadées par les clients dans leurs bilans hebdo n'apparaissaient plus côté coach (le bilan, lui, arrivait bien).
- **Cause** : le fix du 31/05 ajoute les photos **après** l'insert via un `update({photos})` en arrière-plan. Or `bilans` n'avait **aucune policy RLS UPDATE** pour le client authentifié (seulement SELECT + INSERT). Avec RLS, un update non autorisé ne renvoie **pas d'erreur** : il touche 0 ligne en silence. Les photos partaient bien sur Drive (GALLERY), mais leurs URLs n'étaient jamais écrites en base.
- **Fix** (commits `1a56864` + `6c4ffc0`) :
  - Migration `20260607120000_bilans_client_update.sql` : policy `auth_bilans_client_update` (répare aussi l'édition d'un bilan par le client, cassée pareil).
  - `client.html` : l'update photos vérifie maintenant le résultat (`.select('id')` + log si erreur ou 0 ligne) — plus d'échec silencieux.
  - Migration `20260607130000_bilans_recover_photos.sql` : photos perdues (31/05→07/06) retrouvées sur Drive et ré-attachées aux bilans (Clément Corbiere, Jean-Philippe Mallat-Desmortiers ×2, Matys Hoffman, Anthony Laurent, Maxime Gazzera). Vérifié OK par le coach.
- **Règle à retenir** : tout flux client qui fait un UPDATE/DELETE doit avoir sa policy RLS correspondante — un update bloqué par RLS = 0 ligne, **aucune erreur**. Vérifier `data.length` après les updates critiques.
- **Risque résiduel** : si le client ferme l'app avant la fin de l'upload en arrière-plan, les photos non uploadées sont perdues (cas de la photo n°5 d'Anthony).

### Session 2026-07-21 — Thème sombre + couleur de marque (dashboard coach)
- **Réglages → 🎨 Apparence du dashboard** : choix du thème (Clair / Sombre) + couleur de marque (11 pastilles prédéfinies, color-picker natif, champ hex, bouton Réinit.), avec aperçu live.
- Ne concerne **que `dashboard.html`** — `client.html` et `questionnaire.html` sont inchangés.
- **Stockage** : colonnes `settings.theme` + `settings.brand_color` (migration `20260721120000_settings_appearance.sql`), miroir dans `localStorage.fz_appearance` pour appliquer le thème **avant le rendu** (aucun flash).
- **Moteur** : `window.FZ_THEME` (script en `<head>`) pose `data-theme` sur `<html>` et calcule les variantes de la couleur (`--gold-light/-dk/-deep/-deeper/-tint`, `--gold-rgb`, `--on-gold` selon la luminance).
- **Refonte des tokens CSS** : tous les dorés en dur (`#c49a2a`, `#CC9942`, `#b8882a`, `#8a6010`…) → variables ; `background:#fff/white` → `var(--white)` ; `color:var(--dark)` → `var(--text)` (sauf sur fond doré → `var(--on-gold)`) ; `color:var(--white)` → `var(--on-dark)`.
- **Pastilles pastel** : `background:#pastel` → `color-mix(... var(--tint))` et textes foncés → `color-mix(... var(--ink))` ; en sombre `--tint:16%` / `--ink:54%` les assombrit/éclaircit automatiquement.
- Les couleurs "données" (avatars clients, palette de l'équipe, codes macros) restent en dur volontairement.
- Vérifié au navigateur (Playwright) en clair/sombre + couleur alternative : Overview, Clients, Réglages OK.

### Session 2026-07-28 — Roadmap : phase « Peak Week », scroll, semaines vierges
- **Nouvelle phase « Peak Week »** (mauve fluo `rgba(168,60,255,.22)`) dans `roadPhaseColors` + liste `phases` de `renderRoadTab()`. Le menu déroulant, la couleur de ligne et la légende se génèrent depuis ces deux tableaux : ajouter une phase = 2 lignes à modifier.
- **Fix « retour en haut » au changement de phase** : le `<select>` PHASE appelait `sRoad()` **puis** `renderRoadTab()`, alors que `sRoad` re-rendait déjà pour la phase → 2 rebuilds enchaînés ; le 2e mémorisait le `scrollTop=0` de la table fraîchement reconstruite. Désormais le changement de phase ne reconstruit plus rien (`roadPhaseVisual()` met à jour la couleur de la ligne + la carte résumé `#roadSumPhase`), et la position de scroll est conservée entre rendus via `_roadScroll` + verrou `_roadScrollLock` (repositionnement avec `scroll-behavior:auto`).
- **Fix semaines vierges supprimées au refresh** : le nombre de semaines n'existait que dans `window['_roadWeeks_<id>']`, perdu au rechargement ; des semaines ajoutées mais laissées vides ne créant aucune donnée, elles disparaissaient. Total désormais persisté dans `road_<id>._total` (localStorage **et** jsonb `roadmaps.weeks`, pas de migration SQL — la clé `_total` est ignorée par `Number()` dans les calculs de max semaine), écrit dès l'ajout.
- **⚠️ Piège supabase-js v2 (`.catch`)** : une requête `db.from(...).upsert(...)` est *thenable* mais n'expose **ni `.catch` ni `.finally`** → `req.catch(...)` lève un **TypeError synchrone** qui interrompt la fonction appelante (symptôme : « le bouton ne fait plus rien », sans message). 14 appels du dashboard étaient concernés (roadPaste, sauvegarde profil, bilans lus, migration localStorage→Supabase…). Correctif : patch du prototype de base juste après `createClient` (`p.catch = fn => Promise.resolve(this).catch(fn)`), commit `9fefc06`. Préférer malgré tout `.then(({error})=>…)` pour les nouveaux appels.
- **Bouton « 🧹 Nettoyer les vides »** (`roadTrimEmpty()`) : retire les semaines vierges situées **après** la dernière semaine renseignée, minimum 52, avec confirmation. Les semaines vides intercalées sont conservées (numérotation chronologique non décalable).

### Session 2026-07-30 — Fiche client « façon Google Sheet » (onglets en bas + roadmap dense)
Objectif : retrouver la lisibilité / simplicité de l'ancien Google Sheet de coaching, sans casser l'interface existante.
- **Onglets de la fiche client déplacés en bas** (style onglets de feuilles Sheets) : barre fixe `.sh-tabs` (`#detSheetTabs`) **générée** depuis `#detTabs` par `buildSheetTabs()` — un clic en bas déclenche le clic de l'onglet d'origine, donc tous les `render*()` existants tournent sans modification. `syncSheetTabs()` (appelé dans `swDet`) synchronise l'état actif. La barre du haut est masquée via `body.sheet-nav #detTabs{display:none}`.
- Affichage piloté en CSS par `body:has(#detPage.show)` (pas de hook JS sur les ~8 endroits qui ferment la fiche) → nécessite `:has()`, OK Safari 15.4+ / Chrome 105+.
- **Roadmap densifiée** : lignes de 28 px, quadrillage `--border2`, colonnes **SEM + DATE figées** (`thead tr:first-child th:nth-child(1|2)` — attention : la 2e ligne d'en-tête ne contient plus que CARDIO/PAS, les autres `<th>` utilisent `rowspan="2"`, donc ne jamais cibler `.road-table th:nth-child(n)` sans scoper).
- **Cellule PHASE colorée** (comme dans le Sheet) via `roadPhaseStrong` (mêmes teintes, alpha ~2×) + `td.rc-ph{background:var(--ph)}` ; la ligne garde la teinte claire `roadPhaseColors`. Ajouter une phase = 3 tableaux à compléter (`roadPhaseColors`, `roadPhaseStrong`, `phases`).
- **APPORTS sur une seule ligne** (`textarea.rin.rap`, 22 px, centré) qui se déplie à 80 px au focus → plus de lignes hautes.
- **Blocs d'en-tête repliables** (`roadPanel()`, clé `fz_road_panels`) : Résumé affiché par défaut, Objectifs et Légende repliés → la grille commence tout de suite.
- Vérifié au navigateur (Playwright, harnais statique reprenant le `<style>` réel) : clair + sombre, colonnes figées au scroll horizontal.

### Session 2026-08-16 — Propositions de progression au lancement d'une séance (app client)
- Objectif coach : à chaque séance, pousser le client à progresser série par série, à partir de ce qu'il a fait la dernière fois.
- **Le calcul est en JS dans `client.html`, pas dans l'IA** — il doit marcher en salle sans réseau, instantanément, avec des chiffres exacts. `suggestForSet(set)` applique une **double progression** :
  - `parseRepRange()` lit la fourchette prescrite (« 9-12 », « 12 », « 9 à 12 » ; renvoie null sur AMRAP) ;
  - **haut de fourchette atteint → monter la charge** et viser le bas de la fourchette. Seuil = `max-1` si la fourchette est large (écart ≥ 3, donc 11 ET 12 déclenchent sur 9-12, comme demandé), sinon `max` ;
  - sinon → **garder la charge et viser +1 rep** (plafonné au max) ;
  - pas de perf précédente, ou pas de fourchette → **aucune proposition** (on n'invente rien).
  - **Incrément de charge fixe, jamais proportionnel à la charge** (règle du coach) : **+0,5 à 1,25 kg par côté**, soit **+1 à +2,5 kg au total** (`PROG_CHARGE_MIN`/`PROG_CHARGE_MAX`) — un seul épi de charge (T-bar row) = +1,25 kg, qui tombe dans la même fourchette. Au-delà l'exécution se dégrade et la surcharge ne paie plus. L'app affiche donc une **fourchette de charge** (« 80 kg → 81–82,5 kg »), pas un chiffre unique. ⚠️ Ne pas réintroduire de paliers du type +5 kg sur les charges lourdes.
  - Progression en reps : **+1 à 2 reps**, plafonné au haut de la fourchette (« vise 11–12 reps »).
  - `PROG_CHARGE_RULE` rappelée dans le bandeau de séance dès qu'au moins un exercice passe en montée de charge.
- Les perfs précédentes étaient **déjà disponibles** : `startWorkout()` remplissait `prevKg`/`prevReps` par série. Rien à ajouter côté données.
- Affichage : **uniquement pendant la séance lancée** — le coach a fait retirer le gros encart de l'aperçu (trop lourd avant de commencer). Bandeau en tête de séance (phrase IA + `PROG_DISCLAIMER`) + bloc **« À viser aujourd'hui »** sur chaque carte d'exercice (`_renderWoExoCard`). La phrase IA est demandée **une seule fois** au lancement (`startWorkout`), stockée dans `_progTipText` — surtout pas à chaque `renderActiveWorkout()`, qui tourne à chaque série validée.
- **Correctif le même jour — « ça ne marchait pas sur tous les exos »**, deux causes réelles :
  1. `startWorkout()` matchait la perf précédente par **égalité stricte** du nom (`pe.nom===ex.nom`) → toute différence de casse/accent/espace faisait perdre l'historique (et divergeait de l'aperçu, qui faisait déjà un `toLowerCase()`). Une seule fonction désormais : **`normExo()`** (minuscules, sans accents, ponctuation → espaces).
  2. La perf était cherchée **uniquement dans la dernière séance portant le même nom** → aucun objectif pour un exo ajouté au programme depuis, sauté ce jour-là, ou fait dans une autre séance. Remplacé par **`lastPerfFor(nom)`** qui remonte tout l'historique (`trainLogs`, déjà trié du plus récent au plus ancien), ignore les logs `type='activity'` et exige au moins une série renseignée.
  - `parseRepRange()` accepte aussi le **slash** et le `x` (« 9/12 », « 8x12 ») en plus de `-`, `–`, « à ».
  - Quand il n'y a réellement aucun historique, la carte affiche « Première fois sur cet exercice… » — sinon l'absence de proposition passe pour un bug.
- **L'IA ne rédige que la phrase d'intro** : Edge Function `progression-tip` (`claude-opus-5`), qui reçoit les objectifs déjà calculés et n'a pas le droit de citer un chiffre. Cache localStorage par séance + semaine (`progtip:<séance>:<lundi>`), et **repli silencieux** sur le disclaimer seul si l'API ne répond pas — la feature reste utilisable hors-ligne.

### Session 2026-08-14 — Onglet Training refondu : accueil à 2 blocs + suivi des performances façon tableur
- **Accueil de l'onglet** (`window._trainMain='home'`) : (1) un rectangle noir par programme — **le clic ouvre directement le builder** (`editClientProgram`), plus de dépliage ; (2) un rectangle noir **« Suivi des performances »** ; (3) le **graphique des séries par groupe musculaire** du programme courant. Les anciennes vues (Comparaison / Détail séance) restent accessibles depuis la vue perf (`_trainMain='legacy'`) — rien n'a été supprimé.
- **`_renderPerfMatrix()` / `_perfTable()`** — la vue demandée, calquée sur l'ancien Google Sheet :
  - à gauche la séance **prescrite** (# · exercice · série · reps · RIR · repos), colonnes **figées au scroll** (`position:sticky` avec largeurs verrouillées `W=[34,170,46]` / `L=[0,34,204]` — sans largeur fixe les `left:` ne tombent plus juste) ;
  - à droite **une colonne-groupe par séance réalisée** (reps · charge · RIR · note), la plus ancienne d'abord, en-tête date + RPE ;
  - **fond vert / jaune / rouge** par cellule reps et charge, comparé à **la même série de la séance précédente** (`_perfCellBg`) ;
  - notes d'exercice du client, commentaire de séance, **total kg soulevés + nb de séries** par séance ;
  - exos réalisés absents du programme affichés en fin de tableau avec le badge **HORS PROG.** ; séances sans correspondance regroupées sous « Séances hors de ce programme ».
  - Sélecteur de programme quand le client en a plusieurs → suivi par programme (`window._perfProgId`).
- Format lu dans `train_logs.exercises` : `[{nom, note?, unilateral?, sets:[{kg,reps,rir,load,kgL,kgR,repsL,repsR}]}]` — `_perfSetVals()` gère l'unilatéral (max des deux côtés).
- `openDet()` remet `_trainMain='home'` + vide `_perfProgId`/`_cliProgOpen`/`_cliProgDay` : sinon la fiche suivante s'ouvrait sur la vue du client précédent.
- Graphique volume : **barres horizontales triées** (et non verticales comme la maquette) — les noms de groupes musculaires français sont trop longs pour un axe vertical lisible. Une seule série → pas de légende, valeur écrite au bout de chaque barre.
- **Ajustements validés par le coach le même jour** : le graphique de volume est aussi rendu **dans le builder** (`_progRenderVolChart()` appelé par `progRenderDays()`, div `#progVolChart` → recalcul à chaque modif) **et en tête du suivi des performances** ; **encadré rouge (`PERF_FRAME`) autour de chaque séance réalisée** — en-tête, cellules et ligne total — en plus de l'encadré du bloc-séance du programme ; **alternance de fond par exercice** sur toutes les cellules sans couleur de progression (`_perfCellBg(cur,prev,fallback)`), les couleurs vert/jaune/rouge restant prioritaires.

### Session 2026-08-13 (bis) — Onglet Training : plusieurs programmes par client + historique
- L'onglet Training n'affichait que `clientProgs[clientProgs.length-1]` — **un seul programme**. Il liste maintenant **tous** les programmes du client, triés par `createdAt` décroissant (`_renderClientProgCard()`), le plus récent déplié, les anciens repliés = l'historique long terme.
- Chaque carte : badge **VISIBLE** (vert) / **🙈 MASQUÉ**, badge « LE PLUS RÉCENT », nb séances/séries, date de création, volume par muscle. Actions : 👁️ (visible_client), **✏️ Ouvrir** (builder monté inline dans la fiche via `openProgBuilderForClient`), **📋 dupliquer**, ✕ supprimer.
- `duplicateClientProgram()` : copie un programme sous un nouvel id, `visible_client:false` — pour construire le bloc suivant sans écraser l'ancien.
- Bouton **+ Nouveau programme** (`openProgBuilderForClient(null)` → builder vide, client déjà assigné).
- État par programme : `window._cliProgOpen[id]` / `_cliProgDay[id]` (avant : `_clientProgOpen` / `_clientProgDay` globaux, donc un seul programme possible).
- **client.html suit** : plusieurs programmes visibles = plusieurs cartes sur la page d'accueil Entraînement. Nouvelle variable `currentProgIdx` + helper **`curProg()`** — les 10 `programs[0]` en dur ont été remplacés ; `programs` est trié par `created_at` décroissant au chargement. Ne plus jamais écrire `programs[0]` : utiliser `curProg()`.

### Session 2026-08-13 — Onglet « 🤖 Récap » (usage hebdo du client) dans la fiche client
- Nouvel onglet **Récap** (1er après Questionnaire) : en un coup d'œil, comment le client a utilisé l'app cette semaine. `renderRecapTab()` + `recapCollect(offset)` dans `dashboard.html`.
- **Les chiffres sont calculés en JS, pas par l'IA** (fiables, gratuits, instantanés) : rapports quotidiens n/7, séances faites/prévues (programme assigné), activités libres, repas validés/prévus, jours de tracking alimentaire, bilan hebdo envoyé, eau, delta de poids — chaque métrique comparée à la **semaine précédente**. Un score de suivi global (moyenne des taux) + une frise jour par jour (📝 rapport / 💪 séance / 🍽️ tracking).
- **L'IA ne rédige que le commentaire** (Edge Function `weekly-recap`, `claude-opus-5`, déployée avec `--no-verify-jwt`). Le prompt lui interdit d'inventer un chiffre et lui fait produire : 1 phrase de synthèse + « Ce qui va » + « À surveiller » terminé par une action concrète. Testé de bout en bout (~0,02 $ par récap). `max_tokens: 6000` car sur Opus 5 le raisonnement est actif par défaut et partage ce budget.
- **Cache** : table `ai_recaps` (1 ligne par client + semaine). Le résumé se génère **automatiquement** à la première consultation d'une semaine, puis reste figé ; bouton ↻ pour le recalculer. Rien n'est généré si la semaine est totalement vide.
- ⚠️ **Nouveau : `meal_checks`.** La coche « repas mangé » du menu vivait **uniquement en localStorage** → le coach ne pouvait pas la voir. `toggleMealDone()` (client.html) la persiste maintenant en base (non bloquant, localStorage reste le cache optimiste). **L'historique d'avant le 2026-08-13 n'existe pas** : la carte « Repas validés » ne compte qu'à partir de là.
- Migration `20260813120000_weekly_recap.sql` (meal_checks + ai_recaps + RLS), appliquée.
- Piège évité : ne jamais sélectionner une colonne inexistante dans `recapCollect` — PostgREST renvoie une erreur et `data=null`, ce qui afficherait des zéros crédibles. Les erreurs des 6 requêtes sont donc levées explicitement.

### Session 2026-08-12 (quater) — Masquer un plan/programme + précision du poids
- **Masquage client** : colonne `visible_client boolean NOT NULL DEFAULT true` sur `programs` et `plans_full` (migration `20260812150000_visible_client.sql`, appliquée). Le coach garde tout dans son dashboard, le client ne voit que le visible.
  - Le masquage est **réel**, pas cosmétique : policy **RESTRICTIVE** `*_hidden_from_client` (SELECT, authenticated) qui s'ajoute en AND aux policies existantes → coach/admin voient tout, le client ne reçoit pas la ligne. Une RESTRICTIVE évite de recréer les policies permissives existantes (aucun risque de régression).
  - Dashboard : bouton 👁️/🙈 (`visibilityBtn` + `setClientVisibility`) dans les 2 listes globales (`renderProgList`, `renderPlansListPage`) ET dans la fiche client (`loadPlanDisp`, `renderTrainingTab`), avec badge « 🙈 MASQUÉ ».
  - `saveProg()` / `savePlanFull()` reconstruisent l'objet complet : ils doivent **repasser `visible_client`** depuis `existing`, sinon le flag disparaît de l'objet en mémoire après édition.
- **Précision du poids** : la base ne perdait rien (`daily_logs.data` = JSONB, `bilans.poids` = TEXT, `questionnaires.weight_kg` = NUMERIC). Deux vrais coupables :
  1. les champs `<input type="number">` avec `step="0.1"` (et `step` absent = 1 dans le questionnaire) → 79.95 en *stepMismatch* ; passés à **0.01** (suivi quotidien client + coach, roadmap, bilan coach, questionnaire poids/poids cible).
  2. les affichages en `toFixed(1)` / `Math.round(v*10)/10` → helper **`fmtMetric()`** (2 décimales max, sans zéro inutile) dans `client.html` ET `dashboard.html` : accueil client, widget détail (Actuel/Moyenne/Min/Max/Évolution), progression coach (moyennes hebdo, début/fin, badge d'écart, axes du graphique) et **poids moyen auto de la roadmap**.
  - Ne pas remplacer les `toFixed(1)` des **macros** (prot/gluc/lip) : seuls le poids et les mesures sont concernés.

### Session 2026-08-12 (ter) — Couleur de marque de l'app client sans effet
- Le coach change la couleur dans Réglages > Apparence, mais l'app client restait dorée. **Cause** : `client.html` lisait `settings.client_brand_color` en `select` direct, or la **RLS de `settings` bloque la lecture par un client authentifié** — exactement le problème déjà contourné pour `muscle_group_images` (cf. le commentaire à `client.html:1105` et `20260605180000_rpc_muscle_images.sql`). Le `select` renvoyait 0 ligne, sans erreur, donc silencieusement.
- **Fix** : migration `20260812120000_rpc_client_appearance.sql` → RPC `get_coach_appearance(p_coach_id)` SECURITY DEFINER qui renvoie `{client_brand_color, client_theme}`, GRANT à `anon, authenticated`. `client.html` l'appelle après la RPC muscle images (autorité finale sur la couleur + le thème).
- **Règle générale** : toute nouvelle colonne de `settings` que l'app client doit lire passe par une RPC SECURITY DEFINER, jamais par un `select` direct. Restent potentiellement concernés : `gamif_levels`, `activity_types`, `partner`.
- `saveClientAppearance()` (dashboard) affichait l'erreur d'upsert uniquement dans la console → toast ajouté, sinon le coach croit sa couleur enregistrée.

### Session 2026-08-12 — App client : navigation Entraînement en 2 niveaux (liste de séances → aperçu)
- Les **onglets fins de séances** (`.day-tabs` / `.day-tab`) ont d'abord été transformés en carrousel horizontal, puis — à la demande du coach, qui trouvait l'émoji 💪 moche — en **liste verticale** : `.sess-list` / `.sess-row` (pastille numérotée `.sess-num`, nom, « N exercices », chevron SVG). **Aucun émoji** dans cette liste.
- Ouvrir un programme n'affiche plus directement les exercices : on voit **la liste des séances**, et on clique pour ouvrir **l'aperçu** (exercices + bouton « Lancer la séance »). État piloté par `seanceOpen` (bool, ligne ~845) + `currentDayIdx`.
  - `openSeance(i)` ouvre une séance ; `trainBackAction()` remonte d'un cran à la fois : séance → liste → accueil Entraînement → accueil app (et toujours vers l'accueil pendant une séance active, pour ne pas perdre le workout).
  - En vue aperçu, le titre du header devient le **nom de la séance**, avec `.sess-head` (numéro + « Programme · N exercices ») en sous-titre.
  - La carte « LANCER LA PROCHAINE SÉANCE » de l'accueil ouvre directement l'aperçu de la séance 1 (`currentDayIdx=0;seanceOpen=true`).
  - Spacer de 78 px avant `#startWorkoutBtn` : le bouton flottant recouvrait la dernière carte d'exercice.
- ⚠️ `currentDayIdx` est **partagé** avec le plan alimentaire (`setPlanDay()`) — ne pas s'en servir comme état « aucune séance ouverte », d'où la variable `seanceOpen` séparée.
- `.day-tabs` **reste utilisée ailleurs** (historique séances/exercices, jours du plan alimentaire) — ne pas la supprimer.
- **Doublon de bouton Retour supprimé** : le header Entraînement (`#trainBack`) appelle désormais `trainBackAction()` → retour à la page d'accueil de l'onglet si on est dans une sous-vue, sinon vers l'Accueil (et toujours vers l'Accueil pendant une séance active, pour ne pas perdre le workout en cours). Le `backBtn` injecté dans `renderTrainPreview()` est donc vidé.
- `version.json` bumpé (obligatoire dès qu'on touche `client.html`).

### Session 2026-08-02 (bis) — App client : onglet Roadmap + montage avant/après épuré
- **Navbar client** : les onglets *Bonus* et *Calendrier* sont **échangés** ; le 4e onglet garde l'icône calendrier mais s'appelle désormais **« Roadmap »** (nom interne inchangé : `switchTab('Calendar')`, `#btnCalendar`, `#tabCalendar` — ne pas renommer, plusieurs écrans y reviennent).
- L'onglet affiche **la roadmap du coach en lecture seule** (`renderClientRoadmap()`) **au-dessus** du calendrier : table `roadmaps.weeks` avec colonne SEM figée, pastilles de phase colorées (`RM_PHASE_BG` / `RM_PHASE_STRONG`, mêmes teintes que le dashboard), semaine en cours surlignée + auto-scroll. Tout est du texte, aucun champ éditable.
  - Colonnes jamais renseignées par le coach = **masquées** (écran mobile), lignes affichées jusqu'à `max(dernière semaine remplie, semaine en cours)`.
  - Lecture autorisée par la policy existante `auth_roadmaps_client_select` (migration 20260521170000) → **aucune migration nécessaire**, on ajoute juste `weeks` au `select` déjà présent.
  - **MAJ le jour même — plus aucun scroll horizontal** : la table est en `table-layout:fixed` avec des largeurs en **%** (`<colgroup>`), donc les 8 colonnes chiffrées (Sem/Date/Phase/Nutri/Poids/Kcal/Cardio/Pas) tiennent dans la largeur de l'écran (vérifié 360 px et 390 px, `scrollWidth === clientWidth`). Le scroll est **vertical uniquement** (`overflow-x:hidden`).
  - Les champs de **texte libre** du coach (dépense, training, événements, notes) ne peuvent pas tenir en colonne : ils s'affichent en **ligne dépliée sous la semaine** (`tr.rm-sub`, chips `.rm-tag`), et seulement quand ils sont renseignés.
  - **Version finale (lisibilité)** : 8 colonnes forçaient des polices à 7 px → ramené à **5 colonnes** (Sem · Date · Phase · Poids · Kcal) en 13-14 px, une seule ligne par cellule, lignes hautes (~44 px). **Nutrition, Cardio, Pas** rejoignent la ligne secondaire en pastilles `.rm-tag` (11,5 px) avec dépense/training/événements/notes. Règle : sur mobile c'est le NOMBRE de colonnes qui plafonne la taille de police — pour gagner en lisibilité, retirer une colonne, pas réduire la police.
- **Montage avant/après** (dashboard) : à la demande du coach, plus aucun texte — ni prénom, ni écart en semaines, ni dates, ni « FITZONE ÉVOLUTION ». Juste les deux photos côte à côte séparées par un trait doré.
- `version.json` bumpé (obligatoire dès qu'on touche `client.html`).

### Session 2026-08-02 — Galerie : visionneuse plein écran + montage avant/après
- **Visionneuse** (`galOpen/galNav/galClose`) : clic sur une photo → overlay `.gal-lb` dans la page (plus d'ouverture d'onglet Chrome), flèches ‹ › + touches ←/→, Échap pour fermer, compteur « 3 / 12 », titre + date. Les vidéos continuent de s'ouvrir dans un onglet.
- **Comparateur** : bouton « ⇄ Comparer 2 photos » → mode sélection (badges 1/2 sur les vignettes) → « ✓ Valider » → modale de montage **avant/après** au format **Carré 1:1 / Portrait 4:5 / Story 9:16**, bouton « ⇄ Inverser », puis **téléchargement JPEG** prêt pour Instagram. La photo la plus ancienne est placée à gauche automatiquement.
- Montage dessiné sur `<canvas>` (1080 px de large) : en-tête prénom + écart en semaines, deux photos en `cover` séparées par un trait doré, bandeaux AVANT/APRÈS + dates, pied de marque. Couleur dorée reprise de `--gold` (thème du coach).
- **Point clé CORS** : l'export d'un canvas est impossible si une image le « teinte ». `lh3.googleusercontent.com` renvoie `access-control-allow-origin: *` → les photos Drive sont chargées avec `crossOrigin='anonymous'` sur `lh3.../d/<id>=w1600`, avec repli sur les autres formes d'URL. Si l'export échoue quand même, message explicite au lieu d'un échec silencieux.
- `.gs-btn` est désormais une classe autonome (n'était stylée que dans `.gs-bar`, donc invisible dans les modales).
- Vérifié au navigateur (photos factices en data-URL) : navigation clavier/souris, sélection 2 photos, bascule de format, et **téléchargement réel du fichier** `avant-apres-<prénom>-<format>.jpg`.

### Session 2026-07-31 — Builders nutrition & training dans la fiche client + vues tableur
- **Les deux builders s'ouvrent maintenant DANS l'onglet du client** (Nutrition / Training), plus de navigation ni de plein écran. Technique : le nœud unique (`#planBuilderWrap`, `#progBuilderWrap`) est **déplacé** dans un slot de l'onglet (`#pfSlot`, `#progSlot`) par `bldMount()` puis remis à sa place par `bldUnmount()` — les handlers inline continuent de marcher, aucun code dupliqué. Classe `.bld-inline` (position:static !important).
  - ⚠️ Règle : **toujours `bldUnmount()` avant un `innerHTML=` sur l'onglet**, sinon le nœud du builder est détruit et les boutons « Créer un plan/programme » ne font plus rien. `renderNutTab()` et `_renderTrainingContent()` sortent d'ailleurs immédiatement si le builder est monté (`bldIsInline`), et `openDet()`/`goBack()` appellent `bldCloseAll()`.
  - `editClientPlan()` n'ouvre plus le mini-éditeur `renderClientPlanEditor()` (retouches partielles) mais le vrai builder ; `editClientProgram()`/`openProgBuilderForClient()` ne changent plus de page.
  - `setClientTopActions()` restaure les boutons de la barre du haut (les builders écrasent `#tbActs` à l'ouverture).
- **Vue « tableur » (look Google Sheet) par défaut pour les deux builders**, bouton `▦ Tableur / ☰ Fiches` (préférences `fz_pf_view` / `fz_prog_view`) — l'ancienne vue fiches reste disponible et gère seule le running, le drag & drop et les blocs de course.
  - Nutrition `pfRenderSheet()` : REPAS / SOURCE / ALIMENTS / QTÉ / UN. / KCAL / PROT. / GLUC. / LIP. / TOTAUX / NOTES, cellules REPAS+TOTAUX+NOTES fusionnées (`rowspan`), sélecteur du **nombre de repas** et du **nombre de lignes par repas** (clé cosmétique `repas.slots`), recherche d'aliment directement dans la cellule (menu `.gs-menu`), recalcul live sans re-render.
  - Training `progRenderSheet()` : # / EXERCICE / VARIANT / SET / REPS / RIR / REST / MUSCLES / NOTES / VID, une ligne par série, supersets en `1A/1B` sur fond magenta, REST unique par exercice (écrit sur toutes les séries), ligne « NOTES CLIENTS » = `instr`, sélecteur du **nombre de séances**, nom de séance éditable dans la barre dorée.
  - **Aucun changement du modèle de données** → `client.html` est inchangé (pas de bump de `version.json`).
- Styles communs `.gs-*` (barre titre noire, en-têtes dorés, cellules pêche, champs invisibles au repos).
- Vérifié au navigateur avec un **faux client Supabase** (copie instrumentée de `dashboard.html`) : création plan + ajout d'aliment + quantité live + enregistrement, création programme + ajout d'exercice depuis la bibliothèque + enregistrement + réouverture par « Modifier », bascule Tableur/Fiches, et non-régression des pages globales Plans / Programmes.

#### Retours du coach (même jour)
- Grille nutrition : **colonne SOURCE supprimée** (inutile) ; la cellule TOTAUX affiche désormais les **kcal en gros + 3 pastilles P/G/L** (`.gs-tot-cell`, `.gs-chip`) au lieu d'une liste ; largeurs rééquilibrées (ALIMENTS 60 % / NOTES 40 %, flèches des `input[type=number]` masquées dans les grilles).
- Roadmap : **zebra supprimé** (`tbody tr:nth-child(even)`) — seules les couleurs de phase restent.
- Onglet **Progression** : même bouton **« ⤓ Dernière remplie »** (`progScrollToLastFilled()`) qui saute à la dernière semaine renseignée de la vue hebdomadaire (chaque bloc semaine porte `class="dl-week" data-filled="0|1"`). Cherche le conteneur scrollable le plus proche → marche aussi dans la popup Progression.
- Roadmap : bouton **« ⤓ Dernière remplie »** (`roadScrollToLastFilled()`) qui saute à la dernière semaine renseignée (calcul du décalage via `getBoundingClientRect`, ligne placée au tiers haut + flash doré). Évite de scroller 40 semaines.
- Page **Plans alimentaires** : boutons de création ajoutés **dans la page** (`+ Nouveau plan complet` / `+ Nouveau plan macros`) car ceux de la barre du haut passaient inaperçus ; rappel que le client s'attribue dans le champ « Client(s) » du builder.

### Session 2026-08-17 — RIR expliqué + valeurs négatives (client.html)
- **Bouton `i` à côté de « RIR »** dans l'en-tête des séries (séance en cours, exos simples ET supersets, uni- et bilatéral) → `rirInfo()` ouvre une bulle qui explique les *Répétitions En Réserve* : définition, **test des 10 000 €** (« combien de reps de plus tu aurais faites si chacune valait 10 000 € ? »), échelle RIR 3-4 → RIR -1.
- **RIR négatifs autorisés** (ex. `-1` = une rep tentée après l'échec qui n'est pas passée). Les champs RIR passent de `type=number` à `type=text inputmode=numeric` + nettoyage `cleanRir()` (chiffres, `-` en tête uniquement, 3 caractères max) car les pavés numériques mobiles n'ont pas de touche « - ».
- **Bouton `±`** dans le champ RIR (`toggleRirSign()`) pour basculer le signe au doigt ; `onmousedown` neutralisé pour ne pas perdre le focus du champ.
- Fabrique unique `rirCell(ei,si,field,val,ph,gold)` utilisée par les 3 champs RIR (normal, gauche, droite). Le RIR reste stocké **en chaîne** dans `train_logs` → aucun impact sur les données existantes ni sur la logique de progression (qui n'utilise que reps/kg).
- CSS ajoutés : `.i-btn`, `.set-input.rir-in`, `.rir-sign`. `version.json` bumpé.

### Session 2026-08-18 — Pause/reprise de séance + RIR précédents (client.html)
- **Mettre la séance en pause** : bouton `⏸` dans l'en-tête de la séance active + bouton « ⏸ Mettre en pause » sous « Terminer la séance ». `pauseWorkout()` fige le chrono, coupe le timer de repos et écrit tout dans `localStorage.fz_wo_paused` (clé `WO_PAUSE_KEY`).
- **Écran de pause** (`renderPausedWorkout()`) : temps écoulé, séries validées, puis « ▶ Reprendre la séance » / « Terminer et enregistrer » / « Abandonner la séance ».
- **Reprise** (`resumeWorkout()`) : reprend depuis la mémoire si l'app n'a pas été fermée (les vidéos filmées, objets `File` non sérialisables, sont alors conservées), sinon recharge depuis `localStorage` via `applyPausedWorkout()`. Le chrono repart de `workoutStart = Date.now() - workoutElapsed*1000`.
- **Points d'entrée de reprise** : bandeau doré « Séance en pause » sur l'accueil Entraînement, bouton de l'aperçu qui devient « ▶ Reprendre la séance » (`pausedForCurrentDay()`), et `startWorkout()` qui reprend au lieu d'écraser (confirmation si c'est une autre séance).
- **Plus de perte de perfs** : la flèche retour (`endWorkout`) met en pause au lieu de tout jeter ; sauvegarde auto à chaque série validée et quand l'app passe en arrière-plan (`visibilitychange`) ; si l'insert `train_logs` échoue, la séance **repasse en pause** au lieu d'être perdue. Purge auto au bout de 48 h.
- **Nouveaux états** : `workoutPaused`, `workoutElapsed`, `_woSessionName` (nom de séance conservé même si le programme n'est plus résolvable), helpers `woElapsedSec()` / `woSetsDone()` / `pausedWorkout()`.
- **RIR précédents affichés partout** : `prevRir` / `prevRirL` / `prevRirR` stockés au lancement de la séance → le champ RIR affiche en placeholder le RIR de la dernière fois (comme kg et reps) ; le RIR demandé par le coach passe dans une chip **« RIR visé »**. Historique : RIR ajouté au détail unilatéral (G/D) et à la liste « Par exercice » (`_histSetVals()` renvoie désormais `rir`). Helper `rirTxt()` pour que `0` et `-1` ne soient pas confondus avec « vide ».
- `version.json` bumpé.

### Session 2026-08-18 (2) — Deux interfaces pour le rapport quotidien + questions par client
- **Le client choisit son interface** à l'ouverture de l'onglet Suivi : `📝 Questionnaire` (jour par jour, l'existant) ou `📊 Tableau de la semaine`. Choix mémorisé dans `localStorage.fz_suiviView` (`suiviView`, `setSuiviView()`).
- **Tableau hebdo client** (`_renderSuiviTable()`) calqué sur la feuille de suivi du coach : une ligne par jour (Lun→Dim), une colonne par question groupée par section, **scroll horizontal** avec la colonne des jours **figée** (`.wk-fix` sticky), ligne **MOYENNES** noire recalculée en direct pendant la saisie (`_wkUpdateAvg()`).
  - Saisie directe dans les cases (`wkSet()` → `_wkEdits[date][idQuestion]`), cases modifiées surlignées, bouton « Enregistrer (N jours) » qui n'apparaît actif qu'en cas de modification. Jours futurs désactivés.
  - `saveSuiviWeek()` fusionne par date dans `daily_logs` (update si la ligne existe, insert sinon) ; points gamification appliqués uniquement à la journée du jour, `daily_report` seulement si le rapport est complet.
  - **Vider une case n'efface jamais** la valeur déjà enregistrée (même règle que le questionnaire, décision du coach) : la case vidée est ignorée, un toast l'explique et la valeur réapparaît au re-render. Un jour dont toutes les saisies sont vides ne déclenche aucun appel base.
  - Navigation semaine ← / → limitée à **12 semaines en arrière** (`WK_MAX_BACK`) car `dailyLogs` ne charge que 90 jours : au-delà on risquerait d'insérer un doublon au lieu de mettre à jour.
  - **Refonte v2 (même jour)** : le `<table>` + `position:sticky` laissait passer les cellules sous la colonne des jours au scroll horizontal (en-tête et lignes décalés — bug constaté sur iPhone). Remplacé par **deux blocs flex côte à côte** : `.wk-left` (colonne des jours, hors de la zone qui défile) + `.wk-right` (overflow-x). Plus aucun `sticky`. L'alignement ne tient qu'à des **hauteurs de ligne fixes** (`--wk-head/--wk-row/--wk-avg`) et des **largeurs de colonne en px identiques** ligne à ligne (`_wkColW()` : 76 px, 150 px pour le texte) — donc il ne peut plus se décalquer. `scroll-snap-type:x proximity` pour ne pas s'arrêter sur une demi-colonne.
  - En-tête : **une seule ligne par colonne** (section en petit + libellé sur 2 lignes max + unité) au lieu d'une ligne de sections en `colspan` — c'est ce `colspan` qui empêchait de suivre l'ordre du questionnaire.
  - **Colonnes dans l'ordre exact du questionnaire** (`activeDailyQuestions()` sans regroupement). Côté coach, `_renderWeeklyDailyGrid()` regroupe désormais les questions **consécutives** de même section (`runs`) au lieu de toute la section : même ordre que le client, en gardant la barre de sections.
  - Piège CSS : un `<input type=number>` impose sa largeur intrinsèque (~161 px) à sa colonne dans un `<table>` ; `width:100%` + `min-width` ne suffit pas, il faut une largeur explicite (raison de plus d'être passé au flex).
- **Questions activables client par client** : nouvelle colonne `clients.daily_questions` (jsonb, migration `20260818120000_clients_daily_questions.sql`, appliquée). `NULL` = toutes actives (donc rien ne change pour l'existant et les questions ajoutées plus tard sont actives d'office) ; sinon tableau des ids actifs.
  - Coach : bouton **« ⚙️ Questions du rapport (n/N) »** dans l'onglet Progression de la fiche client → modal à cases à cocher par section (`openDailyQModal()` / `saveDailyQuestions()`). Tout coché → on enregistre `null`.
  - Le filtre s'applique partout : questionnaire client, tableau client, grille hebdo du coach, saisie manuelle du coach et sélecteur de métrique du graphique (`activeDailyQuestions()` côté client, `_dlActiveQuestions()` côté dashboard).
- `version.json` bumpé.

### Session 2026-08-20 — Deload, tableau de progression client, RIR décimal
- **Mode deload / phase éphémère sur un programme** (nouvelle colonne `programs.deload` jsonb, migration `20260820120000_programs_deload.sql`, appliquée).
  - Config = `{active, start:'YYYY-MM-DD', weeks, sets:-1, note, exos:{<nom normalisé>:-2}}`. `sets` = séries retirées par défaut, `exos` = override exercice par exercice (0 = on ne retire rien).
  - **La fenêtre est datée** : passée `start + weeks*7`, le programme reprend sa forme normale tout seul, sans que le coach ait à repasser dessus. C'est tout l'intérêt du « éphémère » : rien à défaire.
  - Coach (`dashboard.html`) : encart **🌙 Deload / phase éphémère** dans le builder de programme (sous la Description) — `progRenderDeload()`, état `progDeload`, sauvegardé par `saveProg()`. Liste des exos du programme avec `4 → 3 séries` et boutons −/+/↺. La liste se rafraîchit à chaque `progRenderDay()`.
  - Pastille `dlBadgeHtml()` (DELOAD S1/2 · jusqu'au …) sur les cartes programme de la fiche client et de la liste Programmes ; masquée dès que la phase est passée.
  - Client (`client.html`) : `dlWindow/dlDelta/dlSetCount/dlOf` + `_dlCur` recalculé à chaque rendu. Les séries sont retirées **par la fin**, jamais en dessous de 1. Bandeau « Semaine de décharge (1/2) » sur la liste des séances, l'aperçu et la séance en cours ; chip 🌙 + `Sets: 3 ~~4~~` sur l'exo ; `planProgression()` ne propose que les séries conservées.
  - Le deload est porté par le **programme**, donc partagé par tous les clients qui l'ont : pour n'alléger qu'un client, dupliquer le programme.
- **Vue tableau de la séance** (deuxième interface de saisie, à côté des fiches — bascule `☰ Fiches / ▦ Tableau` en haut de la séance lancée, choix mémorisé dans `localStorage.fz_woView`).
  - `renderWoTable()` : une ligne par série (deux pour un exo unilatéral, G puis D), colonnes « Prévu » (reps/RIR), puis **toutes les séances passées du même nom** (reps/kg/RIR, la plus ancienne à gauche), puis **tout à droite la colonne du jour, vierge et éditable** (kg / reps / RIR / ✓). Le tableau s'ouvre déjà défilé sur cette colonne.
  - Les cellules passées sont comparées à la même série de la séance d'avant : vert = progresse, jaune = maintient, rouge = baisse. Ligne « Volume » en pied, total du jour mis à jour à la frappe (`woCell()` écrit dans `workoutData` **sans re-render**, sinon le champ perdrait le focus).
  - `validateSet()` re-render : la position de défilement est conservée dans `_woTbl` et réappliquée. Bouton `+ série` sur la dernière ligne de chaque exo. Exos au poids du corps : cellule kg = « PdC ». Changer d'exercice / filmer / noter reste dans la vue Fiches (rappelé sous le tableau).
  - Mise en page : patron `.rm2` de la roadmap → classes `.pf2` (+ variante `.pf2.wo`), colonne exercices figée en flex, en-tête synchronisé en JS. **Pas de `<table>`/`sticky`**.
- **RIR à virgule** (demi-RIR) : côté client `cleanRir()` accepte `1,5` / `2.5` (2 chiffres + 1 décimale, signe − conservé), `rirStore()` normalise avec un **point** avant enregistrement, `rirTxt()` réaffiche avec une **virgule**. Champ passé en `inputmode="decimal"`, `maxlength=5`. Côté coach, `_perfSetVals()` parse désormais les virgules (`parseFloat('1,5')` valait 1).
- `version.json` bumpé (2026082001).

### Session 2026-08-23 — Supersets dans la vue tableur du builder de programme
- La vue **▦ Tableur** du builder de programme (`progRenderSheet`, dashboard.html) savait *afficher* les supersets mais pas en *créer un complet* : le ⚡ convertissait l'exo en superset et il n'y avait ensuite aucun moyen d'y ajouter le 2e exercice (le bouton « + Ajouter exercice au superset » n'existait que dans la vue ☰ Fiches).
- Ajouté dans la colonne actions du tableur : bouton **⚡＋** (`progAddToSuperset(sec,idx)`) qui cible le superset — le prochain exercice cliqué dans la bibliothèque de droite y est ajouté. Le bouton s'affiche en violet plein tant que le superset est ciblé (`ssTgt`).
- `progMkSuperset()` cible désormais directement le superset créé (`progExoTarget={sec,idx,superset:true}`) + focus sur la recherche biblio : ⚡ puis clic sur un exo = superset fonctionnel en 2 clics. Il initialise aussi `setsRest` à partir du repos existant.
- Colonne **Variant** : ✕ par ligne (`progDelSupExo`) pour retirer un exo du superset ; s'il n'en reste qu'un, il redevient un exercice simple. Le 🗑 du groupe supprime tout le superset (titre adapté).
- `addExoToDay()` : l'exo ajouté à un superset **s'aligne sur le nb de séries du groupe** (plus de lignes dépareillées dans le tableur) et hérite du repos commun (`setsRest`).
- Modèle de données inchangé (`{superset:true, exercises:[…], setsRest:[…]}`) → rien à changer côté client.

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
- Inputs mobiles : toujours `oninput` (pas `onchange`) pour capturer les valeurs en temps réel
- Ne pas appeler `renderActiveWorkout()` depuis les handlers d'input (re-render complet = perte de focus)
