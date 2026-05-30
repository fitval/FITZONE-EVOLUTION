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
    const dayNames: string[] = config.day_names || ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"];
    const kcal = config.kcal || 2000;
    const prot = config.prot || 150;
    const carb = config.carb || 200;
    const fat = config.fat || 70;
    const dietType = config.diet_type || "omnivore";
    const allergies = config.allergies || [];
    const prepTimeMax = config.prep_time_max || 30;

    const foodDBFull: Array<{nom: string; kcal: number; prot: number; carb: number; fat: number}> = config.food_database || [];
    const foodDB = foodDBFull.slice(0, 200);
    const recipesDBFull: Array<{nom: string; type: string; items: Array<{nom: string; qte: number}>; kcal: number; prot: number}> = config.recipes || [];
    const recipesDB = recipesDBFull.slice(0, 50);

    const foodDBText = foodDB.length > 0
      ? `\n=== BASE DE DONNÉES ALIMENTS DU COACH (${foodDB.length}${foodDBFull.length > foodDB.length ? ' premiers sur ' + foodDBFull.length : ''} aliments) ===
Utilise EN PRIORITÉ ces aliments avec leurs valeurs nutritionnelles exactes :
${foodDB.map(f => `- ${f.nom}: ${f.kcal}kcal P:${f.prot}g G:${f.carb}g L:${f.fat}g /100g`).join("\n")}\n`
      : "";

    const recipesText = recipesDB.length > 0
      ? `\n=== RECETTES DU COACH (PRIORITAIRES — ${recipesDB.length} recettes) ===
⚠️ Tu DOIS utiliser ces recettes en PRIORITÉ dans le plan alimentaire. Pour chaque repas :
1. Cherche d'abord une recette existante qui correspond au type de repas et aux macros cibles
2. ADAPTE les quantités des ingrédients pour coller aux objectifs caloriques/macros du client
3. Vérifie que la recette respecte les allergies/exclusions — si un ingrédient est interdit, remplace-le ou choisis une autre recette
4. Ne crée une recette de zéro QUE si aucune recette existante ne convient
5. Quand tu utilises une recette, UTILISE SON NOM comme nom du repas (ex: "Porridge protéiné" au lieu de "Petit-déjeuner")
6. INCLUS les instructions de préparation de la recette dans le champ "instructions"
7. Si la recette a des instructions, copie-les. Sinon, rédige des instructions de préparation claires et concises.

${recipesDB.map(r => {
  const instr = (r as Record<string, unknown>).instr || "";
  return `- ${r.nom} (${r.type||'repas'}) [${r.kcal}kcal P:${r.prot}g G:${(r as Record<string, unknown>).carb||'?'}g L:${(r as Record<string, unknown>).fat||'?'}g]${instr ? '\n  Instructions: ' + instr : ''}\n  Ingrédients: ${r.items.map(i => `${i.nom} ${i.qte}g`).join(", ")}`;
}).join("\n")}\n`
      : "";

    const clientText = clientProfile
      ? `\n=== PROFIL CLIENT ===
Sexe: ${clientProfile.sex || "non précisé"}, Âge: ${clientProfile.age || "?"}, Poids: ${clientProfile.weight_kg || "?"}kg
Objectif: ${clientProfile.goal || "non précisé"}
${clientProfile.injuries ? "Problèmes de santé: " + clientProfile.injuries : ""}
${clientProfile.food_relationship ? "Relation à la nourriture: " + clientProfile.food_relationship : ""}\n`
      : "";

    // Cibles macro PAR CRÉNEAU (répartition égale, à hitter chaque jour pour ce slot)
    const perSlotKcal = Math.round(kcal / mealsPerDay);
    const perSlotProt = Math.round(prot / mealsPerDay);
    const perSlotCarb = Math.round(carb / mealsPerDay);
    const perSlotFat  = Math.round(fat  / mealsPerDay);
    const slotTargets = mealNames.map(n => `  • ${n} : ${perSlotKcal} kcal · P ${perSlotProt}g · G ${perSlotCarb}g · L ${perSlotFat}g`).join("\n");

    const exampleSlot = mealNames[0];
    const prompt = `Tu es un nutritionniste du sport expert. Génère un plan alimentaire de 7 jours en JSON STRICT.

╔══════════════════════════════════════════════════════════════════╗
║  CONTRAINTE STRUCTURELLE PRIORITAIRE — À RESPECTER AVANT TOUT    ║
╚══════════════════════════════════════════════════════════════════╝

Le plan est STRUCTURÉ PAR CRÉNEAU FIXE. Pour CHAQUE créneau, les apports nutritionnels (kcal, P, G, L) sont CONSTANTS d'un jour à l'autre. Seuls les PLATS varient entre les jours. C'est une règle DURE, prioritaire sur toute notion de "variété".

🎯 CIBLES FIXES PAR CRÉNEAU (à atteindre ±5% CHAQUE JOUR) :
${slotTargets}

EXEMPLE DE CE QUE TU DOIS PRODUIRE pour le créneau « ${exampleSlot} » sur 3 jours (cible ${perSlotKcal} kcal · P ${perSlotProt}g · G ${perSlotCarb}g · L ${perSlotFat}g) :
  ✓ Lundi    — Porridge avoine-myrtilles → ${perSlotKcal} kcal · P ${perSlotProt}g · G ${perSlotCarb}g · L ${perSlotFat}g
  ✓ Mardi    — Œufs brouillés + pain    → ${perSlotKcal} kcal · P ${perSlotProt}g · G ${perSlotCarb}g · L ${perSlotFat}g   ← MÊMES MACROS, plat différent
  ✓ Mercredi — Yaourt grec + granola    → ${perSlotKcal} kcal · P ${perSlotProt}g · G ${perSlotCarb}g · L ${perSlotFat}g   ← MÊMES MACROS, plat différent

CONTRE-EXEMPLE INTERDIT (ce que tu fais souvent par défaut, NE FAIS PAS) :
  ✗ Lundi    — Porridge      → 581 kcal · P 35 · G 80 · L 14
  ✗ Mardi    — Œufs brouillés → 496 kcal · P 36 · G 40 · L 19   ← MACROS DIFFÉRENTES = INTERDIT
  ✗ Mercredi — Yaourt grec    → 371 kcal · P 32 · G 49 · L 5    ← MACROS DIFFÉRENTES = INTERDIT

COMMENT atteindre les cibles : tu CALIBRES les quantités (champ "qte" en grammes) des ingrédients. Si la portion "normale" d'un porridge donne 450 kcal mais que la cible est ${perSlotKcal}, tu AJUSTES la qte des flocons / ajoutes des amandes / de la whey jusqu'à arriver précisément à la cible. Ne te contente jamais d'une portion "standard" — tu dimensionnes chaque plat pour qu'il TOUCHE les cibles du créneau.

VÉRIFIE AVANT DE RETOURNER : pour chaque créneau, additionne les macros de chaque jour à partir des "qte" × valeurs /100g, et confirme qu'elles sont quasi-identiques (±5%). Si l'écart dépasse 5%, REVOIS LES QUANTITÉS.

${clientText}
=== OBJECTIFS NUTRITIONNELS GLOBAUX ===
- Calories: ${kcal} kcal/jour (= ${mealsPerDay} × ${perSlotKcal} kcal)
- Protéines: ${prot}g/jour · Glucides: ${carb}g/jour · Lipides: ${fat}g/jour
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
          "nom": "Porridge protéiné aux fruits",
          "slot": "Petit-déjeuner",
          "instructions": "1. Faire chauffer le lait. 2. Ajouter les flocons et cuire 3min. 3. Ajouter la whey et les fruits.",
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
5. ⚠️ RÈGLE PRIORITAIRE : MACROS PAR CRÉNEAU IDENTIQUES CHAQUE JOUR (cf. encadré CONTRAINTE STRUCTURELLE en début de prompt). Tolérance ±5% par macro. Si ta première version donne des écarts >5%, AJUSTE les quantités avant de retourner le JSON.
6. Varie UNIQUEMENT les PLATS / INGRÉDIENTS entre les jours — JAMAIS les macros par créneau. Variété = nouveau plat, pas nouveaux apports.
7. Respecte strictement les allergies/exclusions
8. Les noms des jours: ${dayNames.join(", ")}
9. Le champ "slot" indique le créneau horaire (${mealNames.join(", ")}). Le champ "nom" est le NOM DE LA RECETTE (ex: "Bowl protéiné", "Poulet grillé légumes rôtis", "Salade César"). Ne mets JAMAIS "Petit-déjeuner" ou "Déjeuner" comme nom — donne un vrai nom de plat.
10. ⚠️ "instructions" est OBLIGATOIRE pour CHAQUE repas, sans exception. Rédige les étapes de préparation prêtes à l'emploi pour le client, même pour un assemblage simple. Ex pour un bowl yaourt-fruits : "1. Verser le yaourt grec dans un bol. 2. Garnir avec les fruits coupés. 3. Saupoudrer d'amandes effilées et arroser de miel." Ex pour un repas viande/légumes : "1. Cuire le poulet à la poêle 6-8 min de chaque côté avec un filet d'huile. 2. Cuire le riz selon les indications du paquet. 3. Faire revenir les légumes à la poêle 5 min. 4. Servir." Pas de repas sans instructions, même les plus simples.
11. Si tu utilises une recette du coach, reprends son nom exact et ses instructions.
Le champ "from_db" indique si l'aliment vient de la base du coach (true) ou est ajouté par l'IA (false).`;

    const client = new Anthropic({ apiKey });

    // Stream from Claude (avoids SDK timeout) but collect all text server-side
    let fullText = "";
    const stream = client.messages.stream({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 20000,
      messages: [{ role: "user", content: prompt }],
    });
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        fullText += event.delta.text;
      }
    }

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

    // FORCE CALIBRATION par créneau : scale chaque repas pour atteindre exactement perSlotKcal
    // (le prompt ne suffit pas à garantir l'identité des macros par slot ; on le force ici).
    // On scale les "qte" par un facteur = perSlotKcal / kcal_actuel du repas.
    // Conséquence : kcal par créneau identique chaque jour ; P/G/L suivent la composition du plat.
    function mealKcal(meal: Record<string, unknown>): number {
      let k = 0;
      const alims = (meal.alims || []) as Array<Record<string, unknown>>;
      for (const a of alims) {
        const q = (Number(a.qte) || 100) / 100;
        k += (Number(a.kcal) || 0) * q;
      }
      return k;
    }
    if (plan.jours && Array.isArray(plan.jours)) {
      for (const jour of plan.jours as Array<Record<string, unknown>>) {
        for (const repas of ((jour.repas || []) as Array<Record<string, unknown>>)) {
          const current = mealKcal(repas);
          if (current <= 0) continue;
          const factor = perSlotKcal / current;
          // garde-fou : on ne scale pas au-delà de [0.5×, 2×] (sinon le plat devient absurde)
          if (factor < 0.5 || factor > 2) continue;
          for (const a of (repas.alims as Array<Record<string, unknown>>)) {
            const qte = Number(a.qte) || 100;
            a.qte = Math.round(qte * factor * 10) / 10; // arrondi 0,1 g
          }
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
