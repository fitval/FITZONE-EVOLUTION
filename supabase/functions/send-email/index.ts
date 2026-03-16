import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SENDER = "Fitzone Evolution <noreply@xn--fitzone-volution-iqb.fr>";

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
    const { email, type, redirect_to } = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Generate the recovery/invite link via admin API
    const linkType = type === "invite" ? "invite" : "recovery";
    const { data, error } = await supabaseAdmin.auth.admin.generateLink({
      type: linkType,
      email,
      options: { redirectTo: redirect_to || "" }
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build the confirmation URL using the hashed_token
    const props = data.properties;
    const confirmUrl = `${supabaseUrl}/auth/v1/verify?token=${props.hashed_token}&type=${linkType}&redirect_to=${encodeURIComponent(redirect_to || "")}`;

    // Email templates
    const baseStyle = `
      <div style="font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Helvetica Neue',sans-serif;max-width:480px;margin:0 auto;padding:32px 20px">
        <div style="text-align:center;margin-bottom:28px">
          <div style="display:inline-block;width:48px;height:48px;background:linear-gradient(135deg,#8a6a1a,#c49a2a);border-radius:12px;line-height:48px;font-size:22px;font-weight:900;color:#1a1916">F</div>
          <div style="font-size:20px;font-weight:800;color:#1a1916;margin-top:8px">FITZONE <span style="color:#c49a2a">EVOLUTION</span></div>
        </div>`;
    const btnStyle = `display:inline-block;padding:14px 32px;background:linear-gradient(135deg,#b8882a,#e8b84a);color:#1a1916;font-weight:700;font-size:15px;text-decoration:none;border-radius:10px`;
    const footer = `<div style="text-align:center;margin-top:28px;font-size:11px;color:#9e9488">Fitzone Evolution &copy; 2025</div></div>`;

    let subject: string;
    let html: string;

    if (type === "invite") {
      subject = "Bienvenue sur Fitzone Evolution !";
      html = `${baseStyle}
        <h2 style="text-align:center;font-size:18px;color:#1a1916;margin-bottom:8px">Ton compte a ete cree !</h2>
        <p style="text-align:center;font-size:14px;color:#6b6456;line-height:1.6;margin-bottom:24px">Clique ci-dessous pour definir ton mot de passe et acceder a ton espace.</p>
        <div style="text-align:center"><a href="${confirmUrl}" style="${btnStyle}">Definir mon mot de passe</a></div>
        <p style="text-align:center;font-size:12px;color:#9e9488;margin-top:20px">Ce lien est valable 24h.</p>
        ${footer}`;
    } else {
      subject = "Reinitialise ton mot de passe";
      html = `${baseStyle}
        <h2 style="text-align:center;font-size:18px;color:#1a1916;margin-bottom:8px">Reinitialisation du mot de passe</h2>
        <p style="text-align:center;font-size:14px;color:#6b6456;line-height:1.6;margin-bottom:24px">Clique ci-dessous pour definir un nouveau mot de passe.</p>
        <div style="text-align:center"><a href="${confirmUrl}" style="${btnStyle}">Reinitialiser mon mot de passe</a></div>
        <p style="text-align:center;font-size:12px;color:#9e9488;margin-top:20px">Si tu n'as pas demande cette reinitialisation, ignore ce message.</p>
        ${footer}`;
    }

    // Send via Resend API
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from: SENDER, to: email, subject, html }),
    });

    const result = await res.json();

    if (!res.ok) {
      console.error("Resend error:", result);
      return new Response(
        JSON.stringify({ error: "Erreur envoi email" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("send-email error:", msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
