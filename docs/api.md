# API en lecture seule — FITZONE ÉVOLUTION

Permet à une application d'un athlète (appelée **de serveur à serveur**) de lire son programme, ses séances,
sa diète et ses pesées. Fermée par défaut : sans clé, tout est refusé.

## Adresse de base

```
https://wsrykmutyhjxdnhnyexl.supabase.co/functions/v1/api
```

Toutes les routes sont sous `/v1/` : par exemple `…/functions/v1/api/v1/me`.

## Clés

- Une clé par athlète, générée par le coach : dashboard → fiche du client → bouton **🔑 API** → « Générer une clé ».
- Format : `fzk_<12 caractères hexadécimaux>_<43 caractères>` (32 octets aléatoires).
- Affichée **une seule fois**. La base n'en garde que l'empreinte SHA-256 : une clé perdue se remplace, elle ne se
  retrouve pas.
- Révocable à tout moment depuis la même fenêtre, qui affiche aussi la date de dernière utilisation.
- La clé se garde **côté serveur** de l'application qui appelle, jamais dans une page web ni une app mobile.

## Règles

| | |
|---|---|
| Authentification | `Authorization: Bearer <clé>` |
| Clé absente, inconnue ou révoquée | `401 {"error":"unauthorized"}` |
| Verbe autre que GET | `405 {"error":"method_not_allowed"}` |
| Adresse inconnue | `404 {"error":"not_found"}` |
| Paramètre invalide | `400 {"error":"bad_request"}` |
| Plus de 60 requêtes par minute et par clé | `429 {"error":"rate_limited"}` + en-tête `Retry-After` |
| Format | JSON UTF-8, dates ISO 8601, kg, kcal, grammes. Pas de CORS. |

Une clé ne lit que les données de **son** athlète. Les notes privées du coach, le contenu des bilans et le reste du
journal quotidien ne sont jamais publiés.

## Exemples

Dans les exemples, la clé est lue depuis une variable d'environnement, jamais écrite en clair :

```bash
export FZ_API="https://wsrykmutyhjxdnhnyexl.supabase.co/functions/v1/api"
export FZ_KEY="…"   # la clé, rangée dans le gestionnaire de secrets de l'application
```

### GET /v1/me

```bash
curl -s "$FZ_API/v1/me" -H "Authorization: Bearer $FZ_KEY"
```

```json
{
  "athlete": { "id": "…", "first_name": "Matys", "goal": "Prise de masse", "coaching_since": "2026-03-01" },
  "updated_at": "2026-10-07T08:00:00.000Z"
}
```

`goal` vient du questionnaire d'intégration, `coaching_since` de la date de début de suivi. `updated_at` est l'heure
de la réponse.

### GET /v1/program

```bash
curl -s "$FZ_API/v1/program" -H "Authorization: Bearer $FZ_KEY"
```

```json
{
  "program": {
    "id": "123",
    "name": "Push Pull Legs, bloc 3",
    "starts_on": null,
    "ends_on": null,
    "week": [
      {
        "day": null,
        "day_index": 1,
        "session_name": "Pull A",
        "exercises": [
          { "name": "Tractions lestées", "sets": 4, "reps": "6-8", "target_load_kg": null, "target_rpe": null,
            "target_rir": 2, "rest_seconds": 150, "notes": null, "section": "workout", "superset": null }
        ]
      }
    ]
  },
  "updated_at": "2026-09-14T08:00:00.000Z"
}
```

- Le programme en cours est le programme **visible** le plus récent du client (le même que dans son app).
  Aucun programme → `"program": null`.
- L'app organise un programme en séances numérotées (Jour 1, Jour 2…), pas en jours de semaine : `day` vaut
  toujours `null` et `day_index` donne l'ordre.
- `section` vaut `warmup`, `workout` ou `cooldown`. Les exercices d'un même superset partagent la même valeur
  `superset` (`"ss1"`, `"ss2"`…), sinon `null`.
- `reps` est une chaîne (`"8"`, `"6-8"`, `"AMRAP"`). `target_rir` = répétitions en réserve visées (1re série).

### GET /v1/sessions

```bash
curl -s "$FZ_API/v1/sessions?from=2026-09-01&to=2026-10-06&page=1&limit=50" -H "Authorization: Bearer $FZ_KEY"
```

```json
{
  "sessions": [
    {
      "id": "456",
      "date": "2026-10-06",
      "name": "Push A",
      "status": "done",
      "duration_minutes": null,
      "exercises": [
        { "name": "Développé couché", "sets": [ { "reps": 6, "load_kg": 80, "rpe": null, "rir": 2 } ] }
      ],
      "athlete_notes": null,
      "updated_at": "2026-10-06T10:15:00.000Z"
    }
  ],
  "page": 1,
  "limit": 50,
  "total": 87
}
```

- Tri du plus récent au plus ancien. `limit` : 50 par défaut, 100 au maximum. `from` et `to` facultatifs (inclus).
- Une séance enregistrée dans l'app est une séance faite : `status` vaut toujours `done`.
- L'app note un RIR par série, pas un RPE : `rpe` vaut `null`, `rir` est fourni.
- `duration_minutes` n'est renseigné que pour les activités (course, vélo…) qui ont une durée saisie.

### GET /v1/diet

```bash
curl -s "$FZ_API/v1/diet" -H "Authorization: Bearer $FZ_KEY"
```

```json
{
  "targets": { "kcal": 2586, "protein_g": 190, "carbs_g": 333, "fat_g": 52, "effective_from": "2026-09-16" },
  "history": [ { "effective_from": "2026-07-27", "kcal": 2365, "protein_g": 181, "carbs_g": 283, "fat_g": 57 } ],
  "meals": [
    {
      "name": "Repas 2",
      "items": [ { "food": "Riz", "grams": 110 }, { "food": "Poulet", "grams": 150 } ],
      "kcal": 693, "protein_g": 46, "carbs_g": 87, "fat_g": 12,
      "notes": "Parmesan interdit"
    }
  ],
  "days": [ { "name": "Jour 1", "meals": [ "…mêmes repas que meals…" ] } ],
  "updated_at": "2026-09-16T08:00:00.000Z"
}
```

- `targets` : le dernier calcul de macros du coach ; `history` : les précédents, du plus récent au plus ancien.
  Aucun calcul → `"targets": null`.
- `meals` : le premier menu du plan alimentaire visible le plus récent. Un plan peut avoir plusieurs menus :
  ils sont tous dans `days`. Les macros d'un repas sont calculées à partir des aliments, arrondies.
- Les équivalences qu'un client a choisies dans son app (aliment remplacé) ne sont pas appliquées : c'est le plan
  du coach qui est publié.

### GET /v1/bodyweight

```bash
curl -s "$FZ_API/v1/bodyweight?from=2026-09-01&to=2026-10-06" -H "Authorization: Bearer $FZ_KEY"
```

```json
{ "measurements": [ { "date": "2026-10-06", "weight_kg": 70.2 } ] }
```

Pesées saisies dans le suivi quotidien, du plus récent au plus ancien. Aucune → `{ "measurements": [] }`.

## Pour le développement

- Code : `supabase/functions/api/` (`routes.ts` = règles d'accès et routes, `format.ts` = JSON publié,
  `index.ts` = lectures en base, toutes filtrées sur le client de la clé).
- Base : `supabase/migrations/20261007120000_api_keys.sql` (table `api_keys`, fonction `api_key_use`).
- Tests : `deno test supabase/functions/api/`
- Déploiement : `npx supabase functions deploy api --no-verify-jwt` (la clé `fzk_…` n'est pas un jeton Supabase :
  c'est la fonction qui vérifie l'appelant).
