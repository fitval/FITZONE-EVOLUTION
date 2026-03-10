# MEMORY — FITZONE EVOLUTION

> Ce fichier est la mémoire vivante du projet. Claude doit le lire au début de chaque session et le mettre à jour après chaque changement significatif.

## État actuel du projet
**Dernière mise à jour** : 2026-03-10

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
- [x] Roadmap 52 semaines par client
- [x] Thème clair avec accents gold
- [x] Overview avec stats

### Ce qui reste à faire (prochaines priorités)
- [ ] **Migration localStorage → Supabase** : exercices, programmes, aliments, repas, plans complets, modules, équipe, settings
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

## Bugs connus
- Aucun bug critique identifié pour le moment

## Notes pour Claude
- Le fondateur est un **coach sportif**, pas un développeur. Explique les choix techniques simplement.
- Il travaille **seul** sur le projet. Pas de code review, pas de CI/CD.
- Le projet est en **français**. Toute l'interface et les messages sont en français.
- **Priorité** : features fonctionnelles > perfection du code. Le but est d'avoir un outil utilisable rapidement.
- Quand tu fais des modifications, **teste mentalement** que rien n'est cassé (pas de tests automatisés).
- **Toujours demander** avant de refactorer du code existant qui fonctionne.
