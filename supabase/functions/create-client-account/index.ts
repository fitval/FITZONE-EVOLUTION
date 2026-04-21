import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SENDER = "Fitzone Evolution <noreply@xn--fitzone-volution-iqb.fr>";
const CLIENT_LOGIN_BASE = "https://fitval.github.io/FITZONE-EVOLUTION/fitzone_deploy/client-login.html";

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

    const { email, first_name, last_name, has_contract, coach_name } = await req.json();
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    const tempPassword = crypto.randomUUID() + "Aa1!";
    let userId: string;
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: { role: "client", first_name, last_name }
    });

    if (authError) {
      if (authError.message.includes("already") || authError.message.includes("exists") || authError.message.includes("unique")) {
        const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
        const existing = existingUsers?.users?.find((u: { email?: string }) => u.email === email);
        if (existing) {
          userId = existing.id;
        } else {
          return new Response(
            JSON.stringify({ error: authError.message }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      } else {
        return new Response(
          JSON.stringify({ error: authError.message }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      userId = authData.user.id;
    }

    // Single CTA: recovery link → client-login.html in "reset" mode
    // After the user sets their password, client-login.html redirects to
    // the right place (contract signing, questionnaire or app) based on status.
    const { data: linkData } = await supabaseAdmin.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: CLIENT_LOGIN_BASE + '?mode=reset' }
    });
    const passwordUrl = linkData
      ? `${supabaseUrl}/auth/v1/verify?token=${linkData.properties.hashed_token}&type=recovery&redirect_to=${encodeURIComponent(CLIENT_LOGIN_BASE + '?mode=reset')}`
      : CLIENT_LOGIN_BASE;

    const coachLine = coach_name ? ` par ${coach_name}` : "";
    const subject = has_contract
      ? "🎉 Ton accompagnement Fitzone est prêt — crée ton mot de passe"
      : "🎉 Bienvenue sur Fitzone Evolution — crée ton mot de passe";

    const nextSteps = has_contract
      ? `
        <div style="background:#fef9e7;border-left:4px solid #c49a2a;padding:14px 16px;border-radius:8px;margin:16px 0;font-size:13px;color:#5c4a18;line-height:1.7">
          Une fois ton mot de passe créé, tu vas enchaîner automatiquement :<br>
          <strong>1.</strong> Signature électronique de ton contrat de coaching<br>
          <strong>2.</strong> Questionnaire d'intégration<br>
          <strong>3.</strong> Accès aux modules vidéo
        </div>`
      : `
        <div style="background:#fef9e7;border-left:4px solid #c49a2a;padding:14px 16px;border-radius:8px;margin:16px 0;font-size:13px;color:#5c4a18;line-height:1.7">
          Une fois ton mot de passe créé, tu accéderas au questionnaire d'intégration puis à tes modules vidéo.
        </div>`;

    const emailHtml = `<div style="font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif;max-width:520px;margin:0 auto;padding:32px 20px;background:#f8f7f3">
      <div style="text-align:center;margin-bottom:28px">
        <div style="display:inline-block;width:48px;height:48px;background:linear-gradient(135deg,#8a6a1a,#c49a2a);border-radius:12px;line-height:48px;font-size:22px;font-weight:900;color:#1a1916">F</div>
        <div style="font-size:20px;font-weight:800;color:#1a1916;margin-top:8px">FITZONE <span style="color:#c49a2a">EVOLUTION</span></div>
      </div>
      <div style="background:white;border-radius:14px;padding:28px 24px;box-shadow:0 1px 3px rgba(0,0,0,.04)">
        <h2 style="text-align:center;font-size:20px;color:#1a1916;margin:0 0 8px">Bienvenue ${first_name || ""} !</h2>
        <p style="text-align:center;font-size:14px;color:#6b6456;line-height:1.6;margin:0 0 8px">Ton espace a été créé${coachLine}. Pour commencer, crée ton mot de passe :</p>
        ${nextSteps}
        <div style="text-align:center;margin:24px 0 12px">
          <a href="${passwordUrl}" style="display:inline-block;padding:16px 36px;background:linear-gradient(135deg,#b8882a,#e8b84a);color:#1a1916;font-weight:800;font-size:15px;text-decoration:none;border-radius:10px">🔐 Définir mon mot de passe</a>
        </div>
        <div style="text-align:center;font-size:11px;color:#9e9488;margin-top:10px">Ce lien est personnel et valable 24h.</div>
      </div>
      <div style="text-align:center;margin-top:24px;font-size:11px;color:#9e9488">Fitzone Evolution &copy; 2025 — Tu reçois cet email car un coach t'a invité(e). Si ce n'est pas toi, ignore-le.</div>
    </div>`;

    if (RESEND_API_KEY) {
      const resendResp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: SENDER, to: email, subject, html: emailHtml }),
      });
      if (!resendResp.ok) {
        const errBody = await resendResp.text();
        console.error("Resend error:", resendResp.status, errBody);
      }
    } else {
      console.warn("RESEND_API_KEY not set — email not sent");
    }

    return new Response(
      JSON.stringify({ user_id: userId, email, email_sent: !!RESEND_API_KEY }),
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
