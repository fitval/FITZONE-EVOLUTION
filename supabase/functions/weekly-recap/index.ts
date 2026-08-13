import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

// Récap hebdo : le dashboard calcule les chiffres, l'IA n'écrit que le commentaire.
// Aucun chiffre n'est inventé ici — le prompt interdit d'en produire d'autres.

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

    const { prenom, objectif, stats } = await req.json();
    if (!stats) {
      return new Response(
        JSON.stringify({ error: "Missing stats" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const client = new Anthropic({ apiKey });

    const prompt = `Tu écris pour un coach sportif qui ouvre la fiche d'un de ses clients. Il veut comprendre en 15 secondes comment ce client a utilisé l'application cette semaine, et quoi lui dire.

CLIENT : ${prenom || "Client"}${objectif ? `\nOBJECTIF : ${objectif}` : ""}

CHIFFRES DE LA SEMAINE (déjà calculés, ne les recalcule pas) :
${JSON.stringify(stats, null, 2)}

Comment lire ces chiffres :
- rapports.faits / 7 : jours où il a rempli son suivi quotidien dans l'app
- seances.faites / seances.prevues : séances de musculation enregistrées vs prévues au programme
- activites.nb : séances libres (cardio, marche, sport) en plus du programme
- repas.valides / repas.prevus : repas du menu qu'il a cochés comme mangés
- tracking.jours / 7 : jours où il a saisi au moins un aliment
- bilan.envoye : a-t-il envoyé son bilan hebdomadaire
- poids.delta : évolution du poids sur la semaine, en kg
- "precedent" : la même valeur la semaine d'avant, pour situer la tendance
- jours[] : le détail jour par jour

RÈGLES :
- Écris en français, en tutoyant le coach ("ton client", "il/elle").
- Aucun chiffre qui ne vient pas des données ci-dessus. Si une donnée vaut 0 ou null, c'est peut-être qu'il n'a rien fait OU que le coach n'a rien prévu (ex : prevues=0 = pas de programme assigné) — ne conclus pas à un abandon dans ce cas, signale simplement qu'il n'y a rien à mesurer.
- Une donnée qui monte ou descend par rapport à "precedent" mérite d'être nommée.
- Pas de félicitations creuses ni de langue de bois : si le suivi est mauvais, dis-le.

FORMAT (exactement 3 parties, pas de titres en gras, pas de markdown) :
1. Une phrase qui résume la semaine.
2. "Ce qui va :" puis 1 à 3 puces courtes commençant par "- ".
3. "À surveiller :" puis 1 à 3 puces courtes commençant par "- ", dont la dernière est une action concrète que le coach peut faire ou dire cette semaine.

Maximum 130 mots au total.`;

    const message = await client.messages.create({
      model: "claude-opus-5",
      max_tokens: 6000, // large : sur Opus 5 le raisonnement est actif par défaut et partage ce budget
      messages: [{ role: "user", content: prompt }],
    });

    // Le classifieur de sûreté peut refuser : content est alors vide
    if (message.stop_reason === "refusal") {
      return new Response(
        JSON.stringify({ error: "Résumé refusé par le modèle" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const summary = message.content
      .filter((b) => b.type === "text")
      .map((b) => (b as { text: string }).text)
      .join("\n")
      .trim();

    if (!summary) {
      return new Response(
        JSON.stringify({ error: "Réponse vide du modèle" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ summary, model: message.model, usage: message.usage }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[WEEKLY-RECAP]", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message || "Erreur inconnue" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
