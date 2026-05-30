import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function repairAndParseJSON(text: string): Record<string, unknown> {
  let s = text.trim();
  if (s.startsWith("```")) s = s.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
  try { return JSON.parse(s); } catch (_) { /* continue */ }
  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start >= 0 && end > start) {
    s = s.substring(start, end + 1);
    try { return JSON.parse(s); } catch (_) { /* continue */ }
  }
  s = s.replace(/,\s*([}\]])/g, "$1");
  s = s.replace(/([{,]\s*)(\w+)\s*:/g, '$1"$2":');
  s = s.replace(/:\s*'([^']*)'/g, ': "$1"');
  try { return JSON.parse(s); } catch (_) { /* continue */ }
  let braces = 0, brackets = 0;
  for (const c of s) {
    if (c === "{") braces++; else if (c === "}") braces--;
    if (c === "[") brackets++; else if (c === "]") brackets--;
  }
  while (brackets > 0) { s += "]"; brackets--; }
  while (braces > 0) { s += "}"; braces--; }
  return JSON.parse(s);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { config, clientProfile } = await req.json();
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

    const nbDays = config.nb_days || 5;
    const dayNames: string[] = config.day_names || [];
    const dayTypes: string[] = config.day_types || [];
    const goal = config.goal || "remise en forme";
    const priorityMuscles = config.priority_muscles || "";
    const experience = config.experience_level || "intermédiaire";
    const sessionDuration = config.session_duration || 60;
    const equipment = config.equipment || "Salle de musculation complète";
    const injuries = config.injuries || "";
    const dislikedExercises = config.disliked_exercises || "";
    const preferences = config.preferences || "";

    const exerciseDB: Array<{nom: string; muscle: string; equip: string; video?: string}> = config.exercise_database || [];
    const exoDBText = exerciseDB.length > 0
      ? `\n=== BIBLIOTHÈQUE D'EXERCICES DU COACH (${exerciseDB.length} exercices) ===
⚠️ RÈGLE ABSOLUE : Tu dois UNIQUEMENT utiliser les exercices de cette liste. Ne propose AUCUN exercice qui n'est pas dans cette bibliothèque. Utilise les noms EXACTS tels qu'écrits ci-dessous :
${exerciseDB.map(e => `- ${e.nom} (${e.muscle || "?"}) [${e.equip || "?"}]`).join("\n")}\n`
      : "";

    const clientText = clientProfile
      ? `\n=== PROFIL CLIENT ===
Sexe: ${clientProfile.sex || "non précisé"}, Âge: ${clientProfile.age || "?"}, Poids: ${clientProfile.weight_kg || "?"}kg, Taille: ${clientProfile.height_cm || "?"}cm
Objectif: ${clientProfile.goal || "non précisé"}
Niveau: ${clientProfile.experience_level || "intermédiaire"}
${clientProfile.injuries ? "Blessures/restrictions: " + clientProfile.injuries : "Pas de blessures connues"}
${clientProfile.previous_program ? "Historique entraînement: " + clientProfile.previous_program : ""}
${clientProfile.daily_steps ? "Pas quotidiens: ~" + clientProfile.daily_steps : ""}
${clientProfile.sleep_hours ? "Sommeil: ~" + clientProfile.sleep_hours + "h" : ""}\n`
      : "";

    const dayDescs = dayNames.map((name: string, i: number) => {
      const type = dayTypes[i] || "muscu";
      return `- ${name}: ${type === "running" ? "Séance running/cardio" : type === "natation" ? "Séance natation" : type === "hybride" ? "Séance hybride (mix cardio+renfo)" : "Séance musculation"}`;
    }).join("\n");

    const prompt = `Tu es un coach sportif expert en programmation d'entraînement. Génère un programme d'entraînement complet en JSON STRICT.
${clientText}
=== PARAMÈTRES DU PROGRAMME ===
- Objectif: ${goal}
- Niveau: ${experience}
${priorityMuscles ? "- Groupe(s) musculaire(s) à PRIORISER: " + priorityMuscles : "- Pas de groupe prioritaire : répartition équilibrée selon l'objectif"}
- Nombre de jours: ${nbDays}
- Durée par séance: ${sessionDuration} minutes
- Équipement disponible: ${equipment}
${injuries ? "- Blessures/restrictions: " + injuries : ""}
${dislikedExercises ? "- Exercices à éviter: " + dislikedExercises : ""}
${preferences ? "- Préférences: " + preferences : ""}

=== PLANNING DES JOURS ===
${dayDescs}
${exoDBText}
=== MÉTHODE DE PROGRAMMATION (à respecter impérativement) ===
PRIORISATION : ${priorityMuscles ? `groupe(s) à prioriser = ${priorityMuscles}. Toute la construction (ordre des exercices, volume, fréquence, split) découle de cette priorité.` : `aucune priorité précise — répartis le volume de façon équilibrée selon l'objectif.`}

1. ORDRE DES EXERCICES dans CHAQUE séance :
   - Commence par 1 ou 2 exercices d'une ZONE SECONDAIRE qui échauffent indirectement la zone principale tout en ajoutant du volume utile (ex : avant une séance dos → crunchs à la poulie ou relevés de jambes, qui échauffent les dorsaux et travaillent les abdos).
   - Enchaîne avec les exercices qui ciblent le GROUPE PRIORITAIRE, en plaçant les exercices polyarticulaires lourds en premier (client frais).
   - Termine par l'isolation et les petits muscles.

2. NOMBRE D'EXERCICES & FRÉQUENCE :
   - Privilégie MOINS d'exercices différents mais répétés avec une FRÉQUENCE de 2x/semaine, plutôt que beaucoup d'exercices vus une seule fois — surtout pour un débutant.
   - Le nombre d'exercices par séance découle du volume visé et de la durée de séance.

3. VOLUME PAR GROUPE MUSCULAIRE (séries/semaine, en additionnant TOUTES les séances) :
   - Groupes peu prioritaires : ~6 séries/semaine (maintien).
   - Groupes prioritaires : 12 à 16 séries/semaine.
   - Pas de chiffre magique, reste dans ces fourchettes.

4. SPLIT (répartition sur les ${nbDays} jours) :
   - Construis le split pour MAXIMISER la fréquence sur le(s) groupe(s) prioritaire(s).
   - Vise une fréquence de 2x/semaine sur l'ENSEMBLE des groupes musculaires si le nombre de jours le permet.

5. TEMPS DE REPOS (exprime-les en secondes, ex : "90s", "180s", "240s") :
   - Petits groupes (mollets, biceps, épaules isolation) : ~90s.
   - Gros exercices polyarticulaires (squat, hack squat, chest press, soulevé de terre) : 180 à 240s.
   - MAIS borne le tout par la durée de séance (${sessionDuration} min) : si la séance est courte, réduis le nombre d'exercices et/ou les repos pour tenir dans le temps imparti. Ne mets JAMAIS 10 exercices à 180s de repos dans une séance de 30 min.

6. SURCHARGE PROGRESSIVE :
   - Ne programme PAS de progression chiffrée. Elle est gérée par le client via la fourchette de répétitions : c'est à lui de monter la charge / les reps à l'intérieur de la fourchette imposée.

=== FOURCHETTES DE RÉPÉTITIONS ===
⚠️ RÈGLE OBLIGATOIRE : Tu dois utiliser UNIQUEMENT ces fourchettes, EXACTEMENT comme écrites (avec tiret, jamais slash) :
- "5-8" — force (exercices lourds polyarticulaires)
- "9-12" — hypertrophie classique
- "10-15" — hypertrophie + endurance musculaire
- "13-16" — endurance musculaire, isolation
- "MAX" — séries au maximum (poids de corps difficiles : dips, tractions, gainage)
- Pour l'échauffement et le cooldown UNIQUEMENT : durées autorisées comme "5min", "30s", "45s"

Aucune autre valeur n'est acceptée : pas de "8-12", pas de "12-15", pas de "6-10", etc. Strictement les 5 fourchettes ci-dessus + durées pour warmup/cooldown.

Choix de la fourchette selon le rôle de l'exercice :
- Polyarticulaires lourds (squat, développé couché, soulevé de terre, hack squat) → "5-8" ou "9-12"
- Isolation (curl, élévations latérales, leg extension) → "10-15" ou "13-16"
- Poids de corps difficiles (tractions, dips) → "MAX" si le client ne peut pas tenir 8 reps, sinon "9-12"
- Adapte au niveau : débutant → fourchettes plus hautes (10-15, 13-16) ; avancé → peut faire du 5-8

⚠️ STRATÉGIE DE 2 FOURCHETTES SUR LE MÊME EXERCICE (recommandée, non obligatoire) :
Pour un même exercice, tu peux utiliser DEUX fourchettes différentes entre les séries — c'est OPTIMAL pour gérer la fatigue et combiner force + volume. Dans ce cas, la fourchette la PLUS COURTE (la plus lourde) vient TOUJOURS sur les PREMIÈRES séries (client frais), puis on passe à la fourchette plus longue (plus légère) sur les dernières séries.
Exemples valides sur 4 séries :
  • Squat : "5-8" / "5-8" / "9-12" / "9-12"  ← lourd d'abord, hypertrophie après
  • Développé incliné : "9-12" / "9-12" / "10-15" / "10-15"
  • Tractions : "MAX" / "MAX" / "9-12" / "9-12"
INTERDIT : passer du léger au lourd ("9-12" puis "5-8" → impossible, le client est déjà fatigué).
INTERDIT : utiliser 3 fourchettes différentes sur un même exercice. Maximum 2.
Si tu n'utilises qu'une seule fourchette pour toutes les séries d'un exercice, c'est OK aussi.

=== FORMAT JSON REQUIS ===
{
  "nom": "Nom du programme",
  "desc": "Description courte du programme",
  "jours": [
    {
      "nom": "Jour 1 — Push",
      "type": "muscu",
      "warmup": [
        {
          "nom": "Rameur",
          "muscle": "Cardio",
          "equip": "Rameur",
          "setsData": [{"reps": "5min", "rest": ""}],
          "notes": "Échauffement progressif",
          "from_db": true
        }
      ],
      "workout": [
        {
          "nom": "Développé couché",
          "muscle": "Pectoraux",
          "equip": "Barre",
          "setsData": [
            {"reps": "5-8", "rest": "180s", "rir": "2"},
            {"reps": "5-8", "rest": "180s", "rir": "1"},
            {"reps": "9-12", "rest": "180s", "rir": "1"},
            {"reps": "9-12", "rest": "180s", "rir": "0"}
          ],
          "notes": "Contrôle la descente, 2s excentrique",
          "from_db": true
        },
        {
          "superset": true,
          "exercises": [
            {
              "nom": "Élévations latérales",
              "muscle": "Épaules",
              "equip": "Haltères",
              "setsData": [
                {"reps": "13-16", "rest": "", "rir": "1"},
                {"reps": "13-16", "rest": "", "rir": "1"},
                {"reps": "13-16", "rest": "", "rir": "0"}
              ]
            },
            {
              "nom": "Face pull",
              "muscle": "Épaules",
              "equip": "Poulie",
              "setsData": [
                {"reps": "13-16", "rest": "", "rir": "1"},
                {"reps": "13-16", "rest": "", "rir": "1"},
                {"reps": "13-16", "rest": "", "rir": "0"}
              ]
            }
          ],
          "setsRest": ["60s", "60s", "60s"]
        }
      ],
      "cooldown": [
        {
          "nom": "Étirements pectoraux",
          "muscle": "Pectoraux",
          "equip": "Aucun",
          "setsData": [{"reps": "30s", "rest": ""}],
          "notes": "Maintenir chaque position",
          "from_db": true
        }
      ]
    },
    {
      "nom": "Jour 2 — Running",
      "type": "running",
      "warmup": [
        {"kind": "run", "label": "Échauffement", "mode": "duration", "duration_min": 10, "intensity": {"kind": "rpe", "value": 4}, "notes": "Trot léger"}
      ],
      "workout": [
        {"kind": "run", "label": "Intervalles", "mode": "intervals", "intervals": {"sets": 1, "reps": 6, "rep_distance_m": 400, "rep_intensity": {"kind": "rpe", "value": 8}, "rest_rep_s": 90, "rest_set_s": 0}, "notes": ""}
      ],
      "cooldown": [
        {"kind": "run", "label": "Retour au calme", "mode": "duration", "duration_min": 5, "intensity": {"kind": "rpe", "value": 3}, "notes": "Marche puis trot léger"}
      ]
    },
    {
      "nom": "Jour 3 — Natation",
      "type": "natation",
      "warmup": [
        {"kind": "run", "label": "Échauffement crawl", "mode": "distance", "distance_m": 200, "intensity": {"kind": "rpe", "value": 4}, "notes": "Nage souple, technique"}
      ],
      "workout": [
        {"kind": "run", "label": "Séries crawl", "mode": "intervals", "intervals": {"sets": 1, "reps": 8, "rep_distance_m": 50, "rep_intensity": {"kind": "rpe", "value": 7}, "rest_rep_s": 20, "rest_set_s": 0}, "notes": "Sprint 50m, repos 20s"}
      ],
      "cooldown": [
        {"kind": "run", "label": "Récupération dos crawlé", "mode": "distance", "distance_m": 100, "intensity": {"kind": "rpe", "value": 3}, "notes": "Nage calme"}
      ]
    }
  ]
}

RÈGLES IMPORTANTES :
1. Retourne UNIQUEMENT du JSON valide, rien d'autre
2. Pour les jours de type "muscu" : utilise le format exercice avec setsData (reps, rest, rir)
3. Pour les jours de type "running" ou "natation" ou "hybride" : utilise le format bloc running avec kind:"run"
4. Pour les supersets : utilise "superset": true avec un tableau "exercises" et "setsRest" pour les repos partagés
5. Les jours "hybride" peuvent mixer des exercices muscu (warmup/cooldown) et des blocs running (workout), ou inversement
6. ⚠️ RÈGLE LA PLUS IMPORTANTE : Utilise UNIQUEMENT les exercices listés dans la BIBLIOTHÈQUE DU COACH ci-dessus. Tu DOIS copier le nom EXACTEMENT comme écrit (mêmes mots, mêmes accents, mêmes majuscules). Aucun exercice "similaire", aucune reformulation, aucune variation de nom. Exemple : si la bibliothèque contient "Développé couché barre", tu écris "Développé couché barre" — pas "Développé couché à la barre", pas "Bench press", pas "Développé couché avec barre". Si tu n'es pas SÛR à 100% que le nom est dans la bibliothèque, NE L'UTILISE PAS — choisis-en un autre dans la liste. Tout exercice non présent EXACTEMENT dans la liste sera AUTOMATIQUEMENT SUPPRIMÉ par le système, laissant des séances incomplètes.
7. Tous les exercices ont "from_db": true (puisqu'ils viennent tous de la bibliothèque — règle 6).
8. ⚠️ FOURCHETTES DE REPS : utilise EXACTEMENT les 5 fourchettes autorisées avec tiret : "5-8", "9-12", "10-15", "13-16", "MAX". JAMAIS d'autres valeurs (pas de "8-12", pas de "6-10", pas de "8/12" avec slash). Une seule fourchette par exercice, OU deux fourchettes avec la plus COURTE en premier (cf. STRATÉGIE DE 2 FOURCHETTES plus haut).
9. Adapte le volume et l'intensité au niveau du client (${experience})
10. Respecte la durée de séance (~${sessionDuration} min)
11. Inclus un échauffement (warmup) et un retour au calme (cooldown) pour chaque jour
12. Varie les exercices entre les jours pour éviter la monotonie
13. Si le client a des blessures, propose des alternatives sûres DEPUIS LA BIBLIOTHÈQUE uniquement
14. Les noms des jours doivent être : ${dayNames.join(", ")}
15. Pour les blocs running/natation, le champ intensity.kind peut être: "pace", "vma", "hr" ou "rpe"`;

    const client = new Anthropic({ apiKey });
    let fullText = "";
    const stream = client.messages.stream({
      model: "claude-sonnet-4-20250514",
      max_tokens: 30000,
      messages: [{ role: "user", content: prompt }],
    });
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        fullText += event.delta.text;
      }
    }

    const plan = repairAndParseJSON(fullText);

    // Normalize structure
    if (plan.jours && Array.isArray(plan.jours)) {
      for (const jour of plan.jours as Array<Record<string, unknown>>) {
        ["warmup", "workout", "cooldown"].forEach(sec => {
          if (!jour[sec] || !Array.isArray(jour[sec])) jour[sec] = [];
        });
      }
    }

    // Normaliser les reps vers les 5 fourchettes autorisées (tiret).
    const ALLOWED_RANGES: Array<[number, number]> = [[5,8],[9,12],[10,15],[13,16]];
    function normalizeReps(raw: unknown): string {
      if (typeof raw !== "string") return String(raw ?? "");
      const s = raw.trim();
      if (!s) return s;
      // durées warmup/cooldown : laisser passer
      if (/^(\d+(?:[.,]\d+)?\s*(min|s|sec))$/i.test(s)) return s;
      const low = s.toLowerCase();
      if (low === "max" || low === "maximum") return "MAX";
      // single number → range qui le contient
      const single = s.match(/^(\d+)$/);
      if (single) {
        const v = parseInt(single[1]);
        for (const [a,b] of ALLOWED_RANGES) if (v >= a && v <= b) return `${a}-${b}`;
        // hors gammes : closest
      }
      // range "a-b" ou "a/b"
      const m = s.match(/^(\d+)\s*[\/\-–—]\s*(\d+)$/);
      if (!m) return s; // format inconnu, laisser
      const a = parseInt(m[1]), b = parseInt(m[2]);
      // map vers la fourchette la plus proche (somme des distances)
      let best: [number, number] = ALLOWED_RANGES[0], bestDist = Infinity;
      for (const r of ALLOWED_RANGES) {
        const d = Math.abs(a - r[0]) + Math.abs(b - r[1]);
        if (d < bestDist) { bestDist = d; best = r; }
      }
      return `${best[0]}-${best[1]}`;
    }
    function normalizeSetsData(ex: Record<string, unknown>) {
      const sets = (ex.setsData || []) as Array<Record<string, unknown>>;
      for (const s of sets) if (s.reps !== undefined) s.reps = normalizeReps(s.reps);
    }

    // FILTRER les exos qui ne sont pas EXACTEMENT dans la bibliothèque du coach
    // (sinon le client se retrouve avec des exos sans vidéo et sans correspondance).
    const libNames = new Set(
      exerciseDB.map(e => (e.nom || "").toString().toLowerCase().trim()).filter(Boolean)
    );
    const inLib = (n: unknown) => libNames.size === 0 || libNames.has((typeof n === "string" ? n : "").toLowerCase().trim());
    const removed: string[] = [];

    if (plan.jours && Array.isArray(plan.jours)) {
      for (const jour of plan.jours as Array<Record<string, unknown>>) {
        for (const sec of ["warmup", "workout", "cooldown"] as const) {
          const items = (jour[sec] || []) as Array<Record<string, unknown>>;
          const kept: Array<Record<string, unknown>> = [];
          for (const item of items) {
            if (item.kind === "run") { kept.push(item); continue; }
            if (item.superset) {
              const subs = (item.exercises || []) as Array<Record<string, unknown>>;
              const subsKept = subs.filter(s => {
                const ok = inLib(s.nom);
                if (!ok) removed.push(String(s.nom));
                if (ok) { s.from_db = true; normalizeSetsData(s); }
                return ok;
              });
              if (subsKept.length === 0) continue; // superset vidé → on saute
              item.exercises = subsKept;
              kept.push(item);
              continue;
            }
            // exo simple
            if (!inLib(item.nom)) { removed.push(String(item.nom)); continue; }
            item.from_db = true;
            normalizeSetsData(item);
            kept.push(item);
          }
          jour[sec] = kept;
        }
      }
    }
    if (removed.length) console.warn("[FILTER] exos retirés (hors bibliothèque) :", removed);

    return new Response(JSON.stringify(plan), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("generate-training-plan error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
