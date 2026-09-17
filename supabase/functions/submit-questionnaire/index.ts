import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { clientAdmin } from "../_shared/securite.ts";

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
    // Pas de contrôle d'appelant : le jeton de fiche valide ci-dessous en tient lieu. Migration de clé seulement.
    const supabase = clientAdmin();

    const { token, data } = await req.json();
    if (!token || !data) {
      return new Response(
        JSON.stringify({ error: "Missing token or data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Find client by token
    const { data: clients, error: clientError } = await supabase
      .from("clients")
      .select("id")
      .eq("token", token)
      .limit(1);

    if (clientError || !clients?.length) {
      return new Response(
        JSON.stringify({ error: "Token invalide" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const clientId = clients[0].id;

    // Insert questionnaire with explicit client_id (UUID from DB, not from user input)
    const payload = { ...data, client_id: clientId };
    // Remove any fields that don't belong
    delete payload.coach_id;

    const { error: insertError } = await supabase
      .from("questionnaires")
      .insert(payload);

    if (insertError) {
      return new Response(
        JSON.stringify({ error: insertError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update client status
    await supabase
      .from("clients")
      .update({ status: "questionnaire_done" })
      .eq("id", clientId);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : "Unknown error";
    console.error("submit-questionnaire error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
