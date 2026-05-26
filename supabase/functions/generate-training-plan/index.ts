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
    const experience = config.experience_level || "intermédiaire";
    const sessionDuration = config.session_duration || 60;
    const equipment = config.equipment || "Salle de musculation complète";
    const injuries = config.injuries || "";
    const dislikedExercises = config.disliked_exercises || "";
    const preferences = config.preferences || "";

    const exerciseDB: Array<{nom: string; muscle: string; equip: string; video?: string}> = config.exercise_database || [];
    const exoDBText = exerciseDB.length > 0
      ? `\n=== BIBLIOTHÈQUE D'EXERCICES DU COACH (${exerciseDB.length} exercices) ===
Utilise EN PRIORITÉ ces exercices avec leurs noms exacts :
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
- Nombre de jours: ${nbDays}
- Durée par séance: ${sessionDuration} minutes
- Équipement disponible: ${equipment}
${injuries ? "- Blessures/restrictions: " + injuries : ""}
${dislikedExercises ? "- Exercices à éviter: " + dislikedExercises : ""}
${preferences ? "- Préférences: " + preferences : ""}

=== PLANNING DES JOURS ===
${dayDescs}
${exoDBText}
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
          "notes": "Échauffement progressif"
        }
      ],
      "workout": [
        {
          "nom": "Développé couché",
          "muscle": "Pectoraux",
          "equip": "Barre",
          "setsData": [
            {"reps": "10", "rest": "90s", "rir": "2"},
            {"reps": "10", "rest": "90s", "rir": "2"},
            {"reps": "10", "rest": "90s", "rir": "1"},
            {"reps": "8", "rest": "120s", "rir": "0"}
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
                {"reps": "15", "rest": "", "rir": "1"},
                {"reps": "15", "rest": "", "rir": "1"},
                {"reps": "12", "rest": "", "rir": "0"}
              ]
            },
            {
              "nom": "Face pull",
              "muscle": "Épaules",
              "equip": "Poulie",
              "setsData": [
                {"reps": "15", "rest": "", "rir": "1"},
                {"reps": "15", "rest": "", "rir": "1"},
                {"reps": "12", "rest": "", "rir": "0"}
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
          "notes": "Maintenir chaque position"
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
6. Utilise EN PRIORITÉ les exercices de la bibliothèque du coach (marque "from_db": true)
7. Adapte le volume et l'intensité au niveau du client (${experience})
8. Respecte la durée de séance (~${sessionDuration} min)
9. Inclus un échauffement (warmup) et un retour au calme (cooldown) pour chaque jour
10. Varie les exercices entre les jours pour éviter la monotonie
11. Si le client a des blessures, propose des alternatives sûres
12. Les noms des jours doivent être : ${dayNames.join(", ")}
13. Le champ "from_db" indique si l'exercice vient de la bibliothèque du coach (true) ou est suggéré par l'IA (false)
14. Pour les blocs running/natation, le champ intensity.kind peut être: "pace", "vma", "hr" ou "rpe"`;

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
