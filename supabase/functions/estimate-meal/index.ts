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

    const { image_base64, media_type, description, plan_macros } = await req.json();

    if (!image_base64 && !description) {
      return new Response(
        JSON.stringify({ error: "Envoie une photo ou une description du repas" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const macrosCtx = plan_macros
      ? `\n\nOBJECTIF NUTRITION DU JOUR :\n- Calories : ${plan_macros.kcal} kcal\n- Protéines : ${plan_macros.prot}g\n- Glucides : ${plan_macros.carb}g\n- Lipides : ${plan_macros.fat}g\n\nCalcule ce qu'il reste à manger après ce repas et donne un conseil pratique pour le reste de la journée.`
      : "";

    const prompt = `Tu es un nutritionniste expert. Estime les calories et macronutriments de ce repas.

INSTRUCTIONS :
1. Identifie le plat / les aliments
2. Estime les quantités en grammes (fourchette réaliste)
3. Donne une FOURCHETTE (min-max) pour les calories et chaque macronutriment
4. Liste les principaux ingrédients détectés avec leurs estimations
5. Si un plan nutrition est fourni, calcule ce qu'il reste à manger dans la journée
6. Donne un conseil pratique pour le reste de la journée
${macrosCtx}

${description ? `DESCRIPTION DU REPAS : ${description}` : ""}

FORMAT JSON REQUIS (retourne UNIQUEMENT du JSON valide, pas de texte ni markdown) :

{
  "nom": "Nom du plat estimé",
  "kcal_min": 500,
  "kcal_max": 700,
  "prot_min": 30,
  "prot_max": 40,
  "carb_min": 50,
  "carb_max": 70,
  "fat_min": 15,
  "fat_max": 25,
  "items": [
    {"nom": "Poulet grillé", "qte_est": "150-200g", "kcal_est": "180-240"}
  ],
  "reste": {
    "kcal": 800,
    "prot": 60,
    "carb": 100,
    "fat": 30
  },
  "conseil": "Pour le reste de la journée, privilégie..."
}`;

    const client = new Anthropic({ apiKey });

    const content: Array<{type: string; source?: {type: string; media_type: string; data: string}; text?: string}> = [];

    if (image_base64) {
      content.push({
        type: "image",
        source: {
          type: "base64",
          media_type: media_type || "image/jpeg",
          data: image_base64,
        },
      });
    }

    content.push({
      type: "text",
      text: prompt,
    });

    const message = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 2000,
      messages: [{ role: "user", content }],
    });

    const textBlock = message.content.find((b: { type: string }) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new Error("No text response from Claude");
    }

    let jsonStr = (textBlock as { type: "text"; text: string }).text.trim();
    if (jsonStr.startsWith("```")) {
      jsonStr = jsonStr.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
    }

    const estimation = JSON.parse(jsonStr);

    return new Response(
      JSON.stringify({ estimation, model: message.model, usage: message.usage }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : "Unknown error";
    console.error("estimate-meal error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
