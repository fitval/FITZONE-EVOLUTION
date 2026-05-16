// send-client-email
// Envoie un email automatique à un client suite à un événement
// (programme prêt, plan nutrition prêt, etc.).
//
// POST body: { coach_id, event, client_id, extra_vars? }
//
// Charge les règles email_rules du coach, filtre celles dont
// trigger.type === 'event' && trigger.event === event && enabled,
// rend les templates avec les variables {first_name}, {last_name},
// {coach_name}, etc., puis envoie via Resend.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SENDER = "Fitzone Evolution <noreply@xn--fitzone-volution-iqb.fr>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderTemplate(tpl: string, vars: Record<string, string>): string {
  return tpl.replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? "").toString());
}

function wrapEmailHtml(bodyText: string): string {
  const safe = escapeHtml(bodyText).replace(/\n/g, "<br>");
  return `<div style="font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Helvetica Neue',sans-serif;max-width:560px;margin:0 auto;padding:32px 20px;color:#1a1916">
    <div style="text-align:center;margin-bottom:28px">
      <div style="display:inline-block;width:48px;height:48px;background:linear-gradient(135deg,#8a6a1a,#c49a2a);border-radius:12px;line-height:48px;font-size:22px;font-weight:900;color:#1a1916">F</div>
      <div style="font-size:18px;font-weight:800;margin-top:8px">FITZONE <span style="color:#c49a2a">EVOLUTION</span></div>
    </div>
    <div style="font-size:15px;line-height:1.65;color:#3a3530;background:#ffffff;padding:24px;border:1px solid #efe9dd;border-radius:12px">${safe}</div>
    <div style="text-align:center;margin-top:24px;font-size:11px;color:#9e9488">Fitzone Evolution &middot; ${new Date().getFullYear()}</div>
  </div>`;
}

async function sendViaResend(to: string, subject: string, html: string): Promise<{ ok: boolean; error?: string }> {
  if (!RESEND_API_KEY) return { ok: false, error: "RESEND_API_KEY not configured" };
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: SENDER, to, subject, html }),
  });
  if (!res.ok) {
    const err = await res.text();
    return { ok: false, error: `Resend ${res.status}: ${err}` };
  }
  return { ok: true };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const body = await req.json();
    const coachId: string | undefined = body.coach_id;
    const event: string | undefined = body.event;
    const clientId: string | undefined = body.client_id;
    const extraVars: Record<string, string> = body.extra_vars || {};

    if (!coachId || !event || !clientId) {
      return new Response(JSON.stringify({ error: "coach_id, event et client_id requis" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Charger les règles + infos du coach + du client
    const [{ data: settings }, { data: client }, { data: coach }] = await Promise.all([
      supabase.from("settings").select("email_rules").eq("coach_id", coachId).maybeSingle(),
      supabase.from("clients").select("id, first_name, last_name, email").eq("id", clientId).eq("coach_id", coachId).maybeSingle(),
      supabase.from("coaches").select("first_name, last_name, gym").eq("id", coachId).maybeSingle(),
    ]);

    if (!client || !client.email) {
      return new Response(JSON.stringify({ ok: false, sent: 0, reason: "client introuvable ou sans email" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const rules = Array.isArray(settings?.email_rules) ? settings!.email_rules : [];
    const matching = rules.filter((r: any) =>
      r && r.enabled !== false && r.trigger?.type === "event" && r.trigger?.event === event
    );

    if (!matching.length) {
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "aucune règle active pour cet événement" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const vars: Record<string, string> = {
      first_name: client.first_name || "",
      last_name: client.last_name || "",
      client_name: `${client.first_name || ""} ${client.last_name || ""}`.trim(),
      coach_name: coach ? `${coach.first_name || ""} ${coach.last_name || ""}`.trim() : "ton coach",
      coach_first_name: coach?.first_name || "",
      gym: coach?.gym || "Fitzone Evolution",
      ...extraVars,
    };

    let sent = 0;
    let failed = 0;
    for (const rule of matching) {
      const subject = renderTemplate(rule.subject || "Un message de ton coach", vars);
      const bodyText = renderTemplate(rule.body || "", vars);
      const html = wrapEmailHtml(bodyText);
      const res = await sendViaResend(client.email, subject, html);
      await supabase.from("email_logs").insert({
        coach_id: coachId,
        client_id: clientId,
        rule_id: rule.id || "unknown",
        event,
        email: client.email,
        subject,
        status: res.ok ? "sent" : "failed",
        error: res.error || null,
      });
      if (res.ok) sent++; else failed++;
    }

    return new Response(JSON.stringify({ ok: failed === 0, sent, failed }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
