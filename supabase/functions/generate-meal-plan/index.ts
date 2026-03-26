import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function repairAndParseJSON(raw: string): Record<string, unknown> {
  // Step 1: Fix unescaped chars inside JSON strings (char-by-char walk)
  let fixed = "", inStr = false, esc = false;
  for (let i = 0; i < raw.length; i++) {
    const c = raw[i];
    if (esc) { fixed += c; esc = false; continue; }
    if (c === "\\" && inStr) { fixed += c; esc = true; continue; }
    if (c === '"') {
      if (!inStr) { inStr = true; fixed += c; continue; }
      // Inside string: check if this quote ends the string or is embedded
      let j = i + 1;
      while (j < raw.length && " \t\r\n".includes(raw[j])) j++;
      const next = raw[j] || "";
      if (":,}]".includes(next) || j >= raw.length) {
        inStr = false; fixed += c;
      } else if (next === '"') {
        // Could be end of string followed by start of next key/value
        // Check if what follows looks like a key or value start
        inStr = false; fixed += c;
      } else {
        // Unescaped quote inside string — escape it
        fixed += '\\"';
      }
      continue;
    }
    if (inStr) {
      if (c === "\n") { fixed += "\\n"; continue; }
      if (c === "\r") { fixed += "\\r"; continue; }
      if (c === "\t") { fixed += "\\t"; continue; }
      const code = c.charCodeAt(0);
      if (code < 32) { fixed += "\\u" + ("0000" + code.toString(16)).slice(-4); continue; }
    }
    fixed += c;
  }

  // Step 2: trailing commas
  fixed = fixed.replace(/,\s*}/g, "}").replace(/,\s*]/g, "]");

  // Step 3: try parse
  try { return JSON.parse(fixed); } catch (_e1) {
    // Step 4: truncation repair
    let s = fixed;
    const last = Math.max(s.lastIndexOf("}"), s.lastIndexOf("]"));
    if (last > 0) s = s.substring(0, last + 1);
    let ob = 0, cb = 0, oa = 0, ca = 0;
    for (const ch of s) { if (ch === "{") ob++; if (ch === "}") cb++; if (ch === "[") oa++; if (ch === "]") ca++; }
    while (ca < oa) { s += "]"; ca++; }
    while (cb < ob) { s += "}"; cb++; }
    s = s.replace(/,\s*}/g, "}").replace(/,\s*]/g, "]");
    return JSON.parse(s);
  }
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "ANTHROPIC_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { config, clientProfile } = await req.json();

    if (!config || !config.kcal || !config.prot) {
      return new Response(
        JSON.stringify({ error: "Missing required config (kcal, prot, carb, fat)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build per-meal targets
    const mealNames: string[] = config.meal_names || ["Petit-déjeuner", "Déjeuner", "Dîner"];
    const mealsCount = mealNames.length;

    // Calculate restaurant meals calorie deduction
    const restaurantSlots: Record<string, string[]> = config.restaurant || {};
    const hasRestaurant = Object.keys(restaurantSlots).length > 0;
    const restaurantMargin = hasRestaurant ? (config.restaurant_margin_kcal || 700) : 0;
    const availableKcal = config.kcal - restaurantMargin;

    // Distribute calories across non-restaurant meal slots
    const nonRestoMeals = mealNames.filter((n: string) => !restaurantSlots[n]);
    const restoMeals = mealNames.filter((n: string) => !!restaurantSlots[n]);

    // Weighted distribution: breakfast ~25%, lunch ~35%, dinner ~30%, snack ~10%
    const weights: Record<string, number> = {
      "Petit-déjeuner": 0.25,
      "Déjeuner": 0.35,
      "Dîner": 0.30,
      "Goûter": 0.05,
      "Collation": 0.05,
      "Collation AM": 0.05,
      "Collation PM": 0.05,
    };

    const totalWeight = nonRestoMeals.reduce((sum: number, n: string) => sum + (weights[n] || 1.0 / mealsCount), 0);
    const mealTargets: { name: string; kcal: number; prot: number; carb: number; fat: number; isRestaurant: boolean; restaurantDays: string[] }[] = [];

    for (const name of mealNames) {
      if (restaurantSlots[name]) {
        mealTargets.push({
          name,
          kcal: Math.round(restaurantMargin / restoMeals.length),
          prot: 0, carb: 0, fat: 0,
          isRestaurant: true,
          restaurantDays: restaurantSlots[name],
        });
      } else {
        const w = weights[name] || 1.0 / mealsCount;
        const slotKcal = Math.round(availableKcal * (w / totalWeight));
        const slotProt = Math.round(config.prot * (w / totalWeight));
        const slotCarb = Math.round(config.carb * (w / totalWeight));
        const slotFat = Math.round(config.fat * (w / totalWeight));
        mealTargets.push({
          name,
          kcal: slotKcal,
          prot: slotProt,
          carb: slotCarb,
          fat: slotFat,
          isRestaurant: false,
          restaurantDays: [],
        });
      }
    }

    // Build the prompt
    const days = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"];
    const dietLabels: Record<string, string> = {
      omni: "Omnivore (tout)",
      vgt: "Végétarien (pas de viande ni poisson)",
      vgn: "Végétalien (aucun produit animal)",
      pes: "Pescétarien (poisson OK, pas de viande)",
    };

    const mealTargetsText = mealTargets
      .filter((m) => !m.isRestaurant)
      .map((m) => `  - ${m.name}: ~${m.kcal} kcal, ~${m.prot}g P, ~${m.carb}g G, ~${m.fat}g L`)
      .join("\n");

    const restaurantText = mealTargets
      .filter((m) => m.isRestaurant)
      .map((m) => `  - ${m.name} (RESTAURANT les ${m.restaurantDays.join(", ")}): budget ~${m.kcal} kcal — ne PAS générer de recette pour ces jours`)
      .join("\n");

    // Build food database section for prompt
    const foodDB: Array<{nom: string; kcal: number; prot: number; carb: number; fat: number; source: string}> = config.food_database || [];
    const recipesDBFull: Array<{nom: string; type: string; items: Array<{nom: string; qte: number}>; kcal: number; prot: number}> = config.recipes || [];
    // Limit to 50 recipes to keep prompt manageable
    const recipesDB = recipesDBFull.slice(0, 50);

    // Limit food DB to 150 items max to keep prompt manageable
    const foodDBLimited = foodDB.slice(0, 150);
    const foodDBText = foodDBLimited.length > 0
      ? `\n=== BASE D'ALIMENTS DU COACH (PRIORITAIRE — ${foodDBLimited.length} aliments) ===
Utilise EN PRIORITÉ ces aliments avec leurs valeurs nutritionnelles EXACTES (pour 100g cru).
Si un aliment existe dans cette base, tu DOIS copier EXACTEMENT ses valeurs kcal/prot/carb/fat.
Tu peux ajouter des aliments hors-base si nécessaire pour la variété, mais marque-les avec "from_db": false.

${foodDBLimited.map(a => `${a.nom}: ${a.kcal}kcal P:${a.prot}g G:${a.carb}g L:${a.fat}g [${a.source}]`).join("\n")}\n`
      : "";

    const recipesText = recipesDB.length > 0
      ? `\n=== RECETTES DU COACH (PRIORITAIRES — ${recipesDB.length} recettes) ===
Tu DOIS utiliser ces recettes en PRIORITÉ dans le plan alimentaire. Pour chaque repas :
1. Cherche d'abord une recette existante qui correspond au type de repas et aux macros cibles
2. ADAPTE les quantités des ingrédients pour coller aux objectifs caloriques/macros du client
3. Vérifie que la recette respecte les allergies/exclusions — si un ingrédient est interdit, remplace-le ou choisis une autre recette
4. Ne crée une recette de zéro QUE si aucune recette existante ne convient

Objectif : utiliser au MAXIMUM les recettes ci-dessous (en ajustant les quantités), plutôt que d'en inventer.

${recipesDB.map(r => `- ${r.nom} (${r.type||'repas'}) [${r.kcal}kcal P:${r.prot}g G:${(r as Record<string, unknown>).carb||'?'}g L:${(r as Record<string, unknown>).fat||'?'}g]: ${r.items.map(i => `${i.nom} ${i.qte}g`).join(", ")}`).join("\n")}\n`
      : "";

    const prompt = `Tu es un diététicien-nutritionniste expert francophone. Génère un plan alimentaire complet de 7 jours en JSON strict.

=== PROFIL CLIENT ===
- Sexe: ${clientProfile?.sex || "non précisé"}
- Âge: ${clientProfile?.age || "non précisé"}
- Poids: ${clientProfile?.weight_kg || "non précisé"} kg
- Objectif: ${clientProfile?.goal || "non précisé"}

=== OBJECTIFS NUTRITIONNELS (validés par le coach) ===
- Total calorique journalier: ${config.kcal} kcal
- Protéines: ${config.prot}g (${config.prot * 4} kcal)
- Glucides: ${config.carb}g (${config.carb * 4} kcal)
- Lipides: ${config.fat}g (${config.fat * 9} kcal)

=== RÉPARTITION PAR REPAS (targets fixes pour CHAQUE jour) ===
${mealTargetsText}
${restaurantText ? `\n=== REPAS RESTAURANT ===\n${restaurantText}\nPour les jours restaurant: marquer is_restaurant: true, alims: [], et ajouter une note "Budget libre — restaurant".\nPour les AUTRES jours de ce même slot: générer une recette normale avec le même target calorique.` : ""}
${foodDBText}${recipesText}
=== CONTRAINTES STRICTES ===
- Régime: ${dietLabels[config.diet_type] || "Omnivore"}
- Aliments/ingrédients INTERDITS (allergies/exclusions): ${(config.allergies || []).length ? config.allergies.join(", ") : "Aucune restriction"}
- Temps de préparation max par recette: ${config.prep_time_max || 30} minutes
- Équipement cuisine disponible: ${(config.equipment || []).length ? config.equipment.join(", ") : "Standard (poêle, four, casserole)"}
${config.preferences ? `- Préférences alimentaires: ${config.preferences}` : ""}

=== MÉTHODE DE CALCUL OBLIGATOIRE ===
AVANT de générer le JSON, tu DOIS suivre cette méthode pour CHAQUE repas de CHAQUE jour :
1. Choisis les aliments et leurs quantités (qte en grammes crus)
2. Pour chaque aliment, calcule: kcal_alim = alim.kcal × alim.qte / 100 (idem pour prot, carb, fat)
3. Additionne les kcal de tous les aliments du repas → c'est le actual_kcal du repas
4. Additionne les actual_kcal de tous les repas du jour → doit être = ${config.kcal} ±15 kcal
5. Si le total du jour dépasse ou est en-dessous de ${config.kcal} ±15 kcal, AJUSTE les quantités (qte) des aliments jusqu'à ce que ce soit correct
6. NE PASSE PAS au jour suivant tant que le total n'est pas dans la tolérance

=== RÈGLES IMPÉRATIVES ===
1. CHAQUE jour doit totaliser EXACTEMENT ${config.kcal} kcal (±15 kcal), ${config.prot}g P (±5g), ${config.carb}g G (±8g), ${config.fat}g L (±3g)
2. CHAQUE slot de repas doit avoir le MÊME target calorique TOUS les 7 jours (permet au client d'interchanger les jours)
3. VARIER les recettes entre les jours (pas le même plat 2 jours de suite)
4. Répartir les protéines uniformément sur tous les repas (minimum 15g de protéines par repas)
5. Toutes les quantités en GRAMMES CRUS (poids avant cuisson)
6. Les valeurs nutritionnelles de chaque aliment sont pour 100g cru
7. Le calcul: actual_kcal du repas = somme de (alim.kcal * alim.qte / 100) pour chaque aliment
8. Vérifier que la somme des actual_kcal de tous les repas = ${config.kcal} ±15 kcal
9. NE JAMAIS utiliser d'aliments de la liste d'exclusions
10. Pour chaque aliment de la base du coach, COPIER les valeurs nutritionnelles EXACTES — ne pas les modifier
11. Instructions de préparation détaillées et appétissantes pour chaque repas
12. Les champs actual_kcal, actual_prot, actual_carb, actual_fat de chaque repas DOIVENT être la SOMME EXACTE calculée à partir des aliments (pas une approximation)

=== FORMAT JSON REQUIS ===
Retourne UNIQUEMENT du JSON valide (pas de texte avant ou après, pas de markdown).
RÈGLES JSON STRICTES :
- N'utilise JAMAIS de guillemets doubles " à l'intérieur des valeurs de texte (utilise des apostrophes ' à la place)
- Pour les retours à la ligne dans les instructions, utilise \\n (séquence échappée), JAMAIS de vrais retours à la ligne
- Pas de virgule après le dernier élément d'un tableau ou objet
Structure exacte :

{
  "jours": [
    {
      "nom": "Lundi",
      "total_kcal": ${config.kcal},
      "total_prot": ${config.prot},
      "total_carb": ${config.carb},
      "total_fat": ${config.fat},
      "repas": [
        {
          "nom": "Petit-déjeuner",
          "target_kcal": 500,
          "actual_kcal": 498,
          "actual_prot": 40,
          "actual_carb": 52,
          "actual_fat": 14,
          "temps_prep": "10 min",
          "outils": ["Bol", "Poêle"],
          "instructions": "1. Faire chauffer la poêle...\\n2. Mélanger les ingrédients...",
          "alims": [
            {
              "nom": "Flocons d'avoine",
              "source": "glucides",
              "kcal": 362,
              "prot": 13.5,
              "carb": 58.7,
              "fat": 7.0,
              "qte": 80,
              "from_db": true
            }
          ]
        }
      ]
    }
  ]
}

IMPORTANT: Les champs total_kcal/total_prot/total_carb/total_fat de chaque jour sont la SOMME des actual_* de ses repas. Ils DOIVENT correspondre.

Les 7 jours sont: ${days.join(", ")}.
Chaque jour a exactement ${mealsCount} repas: ${mealNames.join(", ")}.
Le champ "source" est "proteines", "glucides" ou "lipides" selon le macronutriment dominant de l'aliment.
Le champ "from_db" indique si l'aliment vient de la base du coach (true) ou est ajouté par l'IA (false).`;

    const client = new Anthropic({ apiKey });

    // Stream to keep connection alive, collect text, repair JSON server-side, send clean plan at end
    const stream = await client.messages.stream({
      model: "claude-sonnet-4-20250514",
      max_tokens: 30000,
      messages: [{ role: "user", content: prompt }],
    });

    const encoder = new TextEncoder();
    const readable = new ReadableStream({
      async start(controller) {
        let fullText = "";
        try {
          for await (const event of stream) {
            if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
              fullText += event.delta.text;
              // Send progress (char count) to keep connection alive
              controller.enqueue(encoder.encode("data: " + JSON.stringify({ progress: fullText.length }) + "\n\n"));
            }
          }
          const finalMessage = await stream.finalMessage();

          // Server-side JSON repair
          let jsonStr = fullText.trim();
          if (jsonStr.startsWith("```")) {
            jsonStr = jsonStr.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
          }
          const plan = repairAndParseJSON(jsonStr);

          // Normalise field names
          if (plan.jours) {
            for (const jour of plan.jours) {
              for (const repas of (jour.repas || [])) {
                if (!repas.alims || !Array.isArray(repas.alims) || repas.alims.length === 0) {
                  repas.alims = repas.aliments || repas.ingredients || repas.foods || repas.items || [];
                }
                delete repas.aliments; delete repas.ingredients; delete repas.foods; delete repas.items;
              }
            }
          }

          // Send plan in small chunks to avoid SSE line size issues
          const planStr = JSON.stringify(plan);
          const chunkSize = 8000;
          const totalChunks = Math.ceil(planStr.length / chunkSize);
          for (let ci = 0; ci < totalChunks; ci++) {
            const chunk = planStr.substring(ci * chunkSize, (ci + 1) * chunkSize);
            controller.enqueue(encoder.encode("data: " + JSON.stringify({ pc: chunk, ci, tc: totalChunks }) + "\n\n"));
          }
          controller.enqueue(encoder.encode("data: " + JSON.stringify({ done: true, model: finalMessage.model, usage: finalMessage.usage }) + "\n\n"));
          controller.close();
        } catch (err) {
          controller.enqueue(encoder.encode("data: " + JSON.stringify({ error: err instanceof Error ? err.message : "Unknown error" }) + "\n\n"));
          controller.close();
        }
      }
    });

    return new Response(readable, {
      headers: { ...corsHeaders, "Content-Type": "text/event-stream", "Cache-Control": "no-cache" }
    });
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : "Unknown error";
    console.error("generate-meal-plan error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
