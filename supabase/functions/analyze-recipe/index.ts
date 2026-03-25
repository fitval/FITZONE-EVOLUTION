import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
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

    const { image_base64, media_type, food_database } = await req.json();

    if (!image_base64) {
      return new Response(
        JSON.stringify({ error: "Missing image_base64" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build food catalog for matching
    const foodDB: Array<{nom: string; kcal: number; prot: number; carb: number; fat: number; source: string}> = food_database || [];
    const foodCatalog = foodDB.length > 0
      ? `\n\nCATALOGUE D'ALIMENTS DU COACH (pour matcher les ingrédients) :\n${foodDB.map(a => `- ${a.nom}: ${a.kcal}kcal P:${a.prot}g G:${a.carb}g L:${a.fat}g`).join("\n")}`
      : "";

    const prompt = `Analyse cette image de recette et extrais les informations structurées en JSON.

INSTRUCTIONS :
1. Extrais le NOM de la recette
2. Détermine le TYPE de repas : "petit-dejeuner", "dejeuner", "diner", "collation", "dessert"
3. Extrais TOUS les ingrédients avec leurs quantités en grammes (poids cru)
4. Si les quantités sont en cuillères, tasses, etc. — convertis en grammes approximatifs
5. Si aucune quantité n'est indiquée, estime une quantité raisonnable pour 1 personne
6. Extrais les instructions de préparation étape par étape
7. Estime le temps de préparation
8. Liste les ustensiles/équipements nécessaires
9. Pour chaque ingrédient, donne les valeurs nutritionnelles pour 100g cru (kcal, prot, carb, fat)
10. Détermine la "source" macro dominante de chaque ingrédient : "proteines", "glucides" ou "lipides"
${foodCatalog}

${foodDB.length > 0 ? "IMPORTANT : Si un ingrédient correspond à un aliment du catalogue ci-dessus, utilise EXACTEMENT le même nom et les mêmes valeurs nutritionnelles." : ""}

FORMAT JSON REQUIS (retourne UNIQUEMENT du JSON valide, pas de texte ni markdown) :

{
  "nom": "Nom de la recette",
  "type": "dejeuner",
  "temps_prep": "15 min",
  "outils": ["Poêle", "Bol"],
  "instructions": "1. Étape 1...\\n2. Étape 2...\\n3. Étape 3...",
  "portions": 1,
  "items": [
    {
      "nom": "Blanc de poulet",
      "source": "proteines",
      "kcal": 110,
      "prot": 23.1,
      "carb": 0,
      "fat": 1.2,
      "qte": 200
    }
  ]
}`;

    const client = new Anthropic({ apiKey });

    const message = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4000,
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: image_base64,
            },
          },
          {
            type: "text",
            text: prompt,
          },
        ],
      }],
    });

    const textBlock = message.content.find((b: { type: string }) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new Error("No text response from Claude");
    }

    let jsonStr = (textBlock as { type: "text"; text: string }).text.trim();
    if (jsonStr.startsWith("```")) {
      jsonStr = jsonStr.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
    }

    const recipe = JSON.parse(jsonStr);

    // Calculate total macros
    let totalKcal = 0, totalProt = 0, totalCarb = 0, totalFat = 0;
    (recipe.items || []).forEach((item: {kcal: number; prot: number; carb: number; fat: number; qte: number}) => {
      const ratio = (item.qte || 0) / 100;
      totalKcal += Math.round(item.kcal * ratio);
      totalProt += Math.round(item.prot * ratio * 10) / 10;
      totalCarb += Math.round(item.carb * ratio * 10) / 10;
      totalFat += Math.round(item.fat * ratio * 10) / 10;
    });

    recipe.kcal = totalKcal;
    recipe.prot = Math.round(totalProt);
    recipe.carb = Math.round(totalCarb);
    recipe.fat = Math.round(totalFat);

    return new Response(
      JSON.stringify({ recipe, model: message.model, usage: message.usage }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : "Unknown error";
    console.error("analyze-recipe error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
