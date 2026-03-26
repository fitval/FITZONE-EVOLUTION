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

  // Try direct parse
  try { return JSON.parse(s); } catch (_) { /* continue */ }

  // Find JSON boundaries
  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start >= 0 && end > start) {
    s = s.substring(start, end + 1);
    try { return JSON.parse(s); } catch (_) { /* continue */ }
  }

  // Fix common issues
  s = s.replace(/,\s*([}\]])/g, "$1");
  s = s.replace(/([{,]\s*)(\w+)\s*:/g, '$1"$2":');
  s = s.replace(/:\s*'([^']*)'/g, ': "$1"');

  try { return JSON.parse(s); } catch (_) { /* continue */ }

  // Balance brackets
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

    const mealsPerDay = config.meals_per_day || 4;
    const mealNames = config.meal_names || ["Petit-déjeuner", "Déjeuner", "Collation", "Dîner"];
    const kcal = config.kcal || 2000;
    const prot = config.prot || 150;
    const carb = config.carb || 200;
    const fat = config.fat || 70;
    const dietType = config.diet_type || "omnivore";
    const allergies = config.allergies || [];
    const prepTimeMax = config.prep_time_max || 30;

    const foodDB: Array<{nom: string; kcal: number; prot: number; carb: number; fat: number}> = config.food_database || [];
    const recipesDBFull: Array<{nom: string; type: string; items: Array<{nom: string; qte: number}>; kcal: number; prot: number}> = config.recipes || [];
    const recipesDB = recipesDBFull.slice(0, 50);

    const foodDBText = foodDB.length > 0
      ? `\n=== BASE DE DONNÉES ALIMENTS DU COACH (${foodDB.length} aliments) ===
Utilise EN PRIORITÉ ces aliments avec leurs valeurs nutritionnelles exactes :
${foodDB.map(f => `- ${f.nom}: ${f.kcal}kcal P:${f.prot}g G:${f.carb}g L:${f.fat}g /100g`).join("\n")}\n`
      : "";

    const recipesText = recipesDB.length > 0
      ? `\n=== RECETTES DU COACH (PRIORITAIRES — ${recipesDB.length} recettes) ===
Tu DOIS utiliser ces recettes en PRIORITÉ dans le plan alimentaire. Pour chaque repas :
1. Cherche d'abord une recette existante qui correspond au type de repas et aux macros cibles
2. ADAPTE les quantités des ingrédients pour coller aux objectifs caloriques/macros du client
3. Vérifie que la recette respecte les allergies/exclusions — si un ingrédient est interdit, remplace-le ou choisis une autre recette
4. Ne crée une recette de zéro QUE si aucune recette existante ne convient

${recipesDB.map(r => `- ${r.nom} (${r.type||'repas'}) [${r.kcal}kcal P:${r.prot}g G:${(r as Record<string, unknown>).carb||'?'}g L:${(r as Record<string, unknown>).fat||'?'}g]: ${r.items.map(i => `${i.nom} ${i.qte}g`).join(", ")}`).join("\n")}\n`
      : "";

    const clientText = clientProfile
      ? `\n=== PROFIL CLIENT ===
Sexe: ${clientProfile.sex || "non précisé"}, Âge: ${clientProfile.age || "?"}, Poids: ${clientProfile.weight_kg || "?"}kg
Objectif: ${clientProfile.goal || "non précisé"}
${clientProfile.injuries ? "Problèmes de santé: " + clientProfile.injuries : ""}
${clientProfile.food_relationship ? "Relation à la nourriture: " + clientProfile.food_relationship : ""}\n`
      : "";

    const prompt = `Tu es un nutritionniste du sport expert. Génère un plan alimentaire de 7 jours en JSON STRICT.
${clientText}
=== OBJECTIFS NUTRITIONNELS ===
- Calories: ${kcal} kcal/jour
- Protéines: ${prot}g/jour
- Glucides: ${carb}g/jour
- Lipides: ${fat}g/jour
- Repas par jour: ${mealsPerDay} (${mealNames.join(", ")})
- Régime: ${dietType}
${allergies.length ? "- Allergies/Exclusions: " + allergies.join(", ") : ""}
- Temps de préparation max: ${prepTimeMax} minutes
${foodDBText}${recipesText}
=== FORMAT JSON REQUIS ===
{
  "jours": [
    {
      "nom": "Lundi",
      "repas": [
        {
          "nom": "Petit-déjeuner",
          "alims": [
            {"nom": "Flocons d'avoine", "qte": 80, "kcal": 68, "prot": 2.4, "carb": 12, "fat": 1.4, "source": "coach_db", "from_db": true}
          ]
        }
      ]
    }
  ]
}

RÈGLES IMPORTANTES :
1. Retourne UNIQUEMENT du JSON valide, rien d'autre
2. Les valeurs kcal/prot/carb/fat sont pour 100g de l'aliment
3. "qte" est la quantité en grammes à consommer
4. Utilise "from_db": true si l'aliment vient de la base du coach, false sinon
5. Les macros de chaque jour doivent être proches des objectifs (±5%)
6. Varie les repas entre les jours
7. Respecte strictement les allergies/exclusions
8. Les noms des jours: Lundi, Mardi, Mercredi, Jeudi, Vendredi, Samedi, Dimanche
9. Les noms des repas: ${mealNames.join(", ")}
Le champ "from_db" indique si l'aliment vient de la base du coach (true) ou est ajouté par l'IA (false).`;

    const client = new Anthropic({ apiKey });

    // Non-streaming: simpler, avoids SSE parsing issues
    const message = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 30000,
      messages: [{ role: "user", content: prompt }],
    });

    const fullText = message.content
      .filter((b: {type: string}) => b.type === "text")
      .map((b: {type: string; text?: string}) => (b as {type: string; text: string}).text)
      .join("");

    // Server-side JSON repair
    const plan = repairAndParseJSON(fullText);

    // Normalise field names
    if (plan.jours && Array.isArray(plan.jours)) {
      for (const jour of plan.jours as Array<Record<string, unknown>>) {
        for (const repas of ((jour.repas || []) as Array<Record<string, unknown>>)) {
          if (!repas.alims || !Array.isArray(repas.alims) || (repas.alims as unknown[]).length === 0) {
            repas.alims = repas.aliments || repas.ingredients || repas.foods || repas.items || [];
          }
          delete repas.aliments; delete repas.ingredients; delete repas.foods; delete repas.items;
        }
      }
    }

    return new Response(JSON.stringify(plan), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("generate-meal-plan error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
