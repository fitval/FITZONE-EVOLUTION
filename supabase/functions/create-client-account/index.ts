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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const { email, first_name, last_name } = await req.json();
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Create auth user
    const tempPassword = crypto.randomUUID() + "Aa1!";
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: { role: "client", first_name, last_name }
    });

    if (authError) {
      return new Response(
        JSON.stringify({ error: authError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate recovery link
    const redirectTo = "https://fitval.github.io/FITZONE-EVOLUTION/fitzone_deploy/client-login.html";
    const { data: linkData } = await supabaseAdmin.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo }
    });

    // Send invitation email via Resend
    if (linkData) {
      const confirmUrl = `${supabaseUrl}/auth/v1/verify?token=${linkData.properties.hashed_token}&type=recovery&redirect_to=${encodeURIComponent(redirectTo + '?mode=reset')}`;
      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: SENDER,
          to: email,
          subject: "Bienvenue sur Fitzone Evolution !",
          html: `<div style="font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif;max-width:480px;margin:0 auto;padding:32px 20px">
            <div style="text-align:center;margin-bottom:28px">
              <div style="display:inline-block;width:48px;height:48px;background:linear-gradient(135deg,#8a6a1a,#c49a2a);border-radius:12px;line-height:48px;font-size:22px;font-weight:900;color:#1a1916">F</div>
              <div style="font-size:20px;font-weight:800;color:#1a1916;margin-top:8px">FITZONE <span style="color:#c49a2a">EVOLUTION</span></div>
            </div>
            <h2 style="text-align:center;font-size:18px;color:#1a1916;margin-bottom:8px">Ton compte a ete cree !</h2>
            <p style="text-align:center;font-size:14px;color:#6b6456;line-height:1.6;margin-bottom:24px">Bienvenue ${first_name || ""} ! Clique ci-dessous pour definir ton mot de passe et acceder a ton espace.</p>
            <div style="text-align:center"><a href="${confirmUrl}" style="display:inline-block;padding:14px 32px;background:linear-gradient(135deg,#b8882a,#e8b84a);color:#1a1916;font-weight:700;font-size:15px;text-decoration:none;border-radius:10px">Definir mon mot de passe</a></div>
            <p style="text-align:center;font-size:12px;color:#9e9488;margin-top:20px">Ce lien est valable 24h.</p>
            <div style="text-align:center;margin-top:28px;font-size:11px;color:#9e9488">Fitzone Evolution &copy; 2025</div>
          </div>`
        }),
      });
    }

    return new Response(
      JSON.stringify({ user_id: authData.user.id, email: authData.user.email }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : "Unknown error";
    console.error("create-client-account error:", errMsg);
    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
