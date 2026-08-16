import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

// Une à deux phrases pour introduire les objectifs de la séance.
// Les CHIFFRES sont calculés dans l'app (client.html → suggestForSet) : le modèle
// ne fait que les commenter, et n'a pas le droit d'en produire d'autres.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { prenom, seance, objectifs } = await req.json();
    if (!Array.isArray(objectifs) || !objectifs.length) {
      return new Response(JSON.stringify({ error: "Aucun objectif à commenter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const lignes = objectifs.map((o: { nom: string; charge: number; reps: number }) =>
      o.charge > 0
        ? `- ${o.nom} : passer à ${o.charge} kg`
        : `- ${o.nom} : viser ${o.reps} répétitions de plus`
    ).join("\n");

    const client = new Anthropic({ apiKey });
    const message = await client.messages.create({
      model: "claude-opus-5",
      max_tokens: 4000, // large : le raisonnement est actif par défaut et partage ce budget
      messages: [{
        role: "user",
        content: `Tu écris pour un pratiquant de musculation qui ouvre sa séance dans son application. Les objectifs ci-dessous ont déjà été calculés par l'app à partir de sa dernière séance.

PRATIQUANT : ${prenom || "l'athlète"}
SÉANCE : ${seance || "Séance"}
OBJECTIFS DU JOUR :
${lignes}

Écris UNE seule phrase (deux au maximum), en français, en tutoyant, qui donne le cap de la séance.

RÈGLES :
- Ne répète pas la liste et ne cite aucun chiffre : ils sont déjà affichés juste en dessous.
- Dis où se joue l'essentiel du travail aujourd'hui (ex : plusieurs exercices prêts à monter en charge, ou une séance où l'on cherche des répétitions).
- Ton direct, factuel, sans emoji, sans exclamation, sans félicitations creuses.
- Maximum 30 mots.`,
      }],
    });

    if (message.stop_reason === "refusal") {
      return new Response(JSON.stringify({ error: "Refusé par le modèle" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const tip = message.content
      .filter((b) => b.type === "text")
      .map((b) => (b as { text: string }).text)
      .join(" ")
      .trim();

    if (!tip) {
      return new Response(JSON.stringify({ error: "Réponse vide" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ tip, model: message.model }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    console.error("[PROGRESSION-TIP]", err);
    return new Response(JSON.stringify({ error: (err as Error).message || "Erreur inconnue" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
