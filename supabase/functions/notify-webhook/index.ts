import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const EVENT_LABELS: Record<string, string> = {
  recruitment_response: "Pré-diagnostic complété",
  questionnaire_submitted: "Questionnaire d'intégration soumis",
  bilan_submitted: "Bilan hebdomadaire soumis",
  contract_signed: "Contrat signé",
  test: "Test de webhook",
};
const EVENT_COLORS: Record<string, number> = {
  recruitment_response: 0xc49a2a,
  questionnaire_submitted: 0x2563eb,
  bilan_submitted: 0x059669,
  contract_signed: 0x7c3aed,
  test: 0x6b7280,
};

function truncate(s: string, n: number) {
  if (typeof s !== "string") s = String(s);
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

function fmtAnswer(val: unknown): string {
  if (val == null) return "—";
  if (Array.isArray(val)) return val.length ? val.map(String).join(", ") : "—";
  if (typeof val === "object") return JSON.stringify(val);
  const s = String(val).trim();
  return s || "—";
}

function isDiscord(url: string): boolean {
  return /discord(?:app)?\.com\/api\/webhooks\//.test(url);
}

function buildDiscordPayload(event: string, data: any) {
  const fields: { name: string; value: string; inline?: boolean }[] = [];
  const eventLabel = EVENT_LABELS[event] || event;
  const color = EVENT_COLORS[event] || 0xc49a2a;
  let title = `🔔 ${eventLabel}`;
  let description = "";

  if (event === "recruitment_response") {
    title = "📋 Nouveau pré-diagnostic complété";
    description = data.form_title ? `**${data.form_title}**` : "";
    const name = `${data.first_name || ""} ${data.last_name || ""}`.trim() || "—";
    fields.push({ name: "👤 Candidat", value: truncate(name, 256), inline: true });
    if (data.email) fields.push({ name: "✉️ Email", value: truncate(data.email, 256), inline: true });
    if (data.phone) fields.push({ name: "📞 Téléphone", value: truncate(data.phone, 256), inline: true });
    const questions = Array.isArray(data.questions) ? data.questions : [];
    const answers = data.answers || {};
    const slots = 25 - fields.length;
    questions.slice(0, slots).forEach((q: any) => {
      fields.push({
        name: truncate(q.label || q.id || "Question", 256),
        value: truncate(fmtAnswer(answers[q.id]), 1024),
        inline: false,
      });
    });
  } else if (event === "questionnaire_submitted") {
    title = "📋 Questionnaire d'intégration soumis";
    const name = `${data.first_name || ""} ${data.last_name || ""}`.trim() || "—";
    description = `Client : **${name}**`;
    if (data.email) fields.push({ name: "✉️ Email", value: truncate(data.email, 256), inline: true });
    if (data.goal) fields.push({ name: "🎯 Objectif", value: truncate(String(data.goal), 256), inline: true });
    if (data.weight_kg) fields.push({ name: "⚖️ Poids", value: `${data.weight_kg} kg`, inline: true });
    if (data.weight_goal) fields.push({ name: "🎯 Poids cible", value: `${data.weight_goal} kg`, inline: true });
    if (data.activity_level) fields.push({ name: "🏃 Activité", value: truncate(String(data.activity_level), 256), inline: true });
    if (data.experience_level) fields.push({ name: "💪 Expérience", value: truncate(String(data.experience_level), 256), inline: true });
  } else if (event === "bilan_submitted") {
    title = "📊 Bilan hebdomadaire reçu";
    const name = `${data.first_name || ""} ${data.last_name || ""}`.trim() || data.client_name || "—";
    description = `Client : **${name}**`;
    if (data.date) fields.push({ name: "📅 Date", value: data.date, inline: true });
    if (data.attitude) fields.push({ name: "🧠 Attitude", value: `${data.attitude}/10`, inline: true });
    if (data.weight) fields.push({ name: "⚖️ Poids", value: `${data.weight} kg`, inline: true });
  } else if (event === "test") {
    title = "✅ Test de webhook";
    description = "Si tu vois ce message, le webhook est bien configuré.";
  } else {
    description = JSON.stringify(data).slice(0, 1900);
  }

  return {
    embeds: [
      {
        title,
        description: description ? truncate(description, 4096) : undefined,
        color,
        fields,
        timestamp: new Date().toISOString(),
        footer: { text: "FITZONE EVOLUTION" },
      },
    ],
  };
}

function buildGenericPayload(event: string, data: any) {
  return {
    event,
    event_label: EVENT_LABELS[event] || event,
    timestamp: new Date().toISOString(),
    data,
  };
}

async function postToWebhook(url: string, event: string, data: any): Promise<Response> {
  const payload = isDiscord(url) ? buildDiscordPayload(event, data) : buildGenericPayload(event, data);
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const body = await req.json();
    const coachId: string | undefined = body.coach_id;
    const event: string = body.event || "";
    const data = body.data || {};
    const testWebhookUrl: string | undefined = body.test_webhook_url;

    if (!event) {
      return new Response(JSON.stringify({ error: "event manquant" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Mode TEST direct (depuis le dashboard) : envoie un ping sur l'URL fournie
    if (event === "test" && testWebhookUrl) {
      const resp = await postToWebhook(testWebhookUrl, "test", {});
      return new Response(JSON.stringify({ ok: resp.ok, status: resp.status }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!coachId) {
      return new Response(JSON.stringify({ error: "coach_id manquant" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: settings, error: sErr } = await supabase
      .from("settings")
      .select("notifications")
      .eq("coach_id", coachId)
      .maybeSingle();

    if (sErr) {
      return new Response(JSON.stringify({ error: sErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const all = Array.isArray(settings?.notifications) ? settings!.notifications : [];
    const targets = all.filter((w: any) =>
      w && w.enabled !== false && Array.isArray(w.events) && w.events.includes(event) && typeof w.url === "string" && w.url.length > 0
    );

    if (!targets.length) {
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "no matching webhook" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const results = await Promise.allSettled(targets.map((w: any) => postToWebhook(w.url, event, data)));
    const sent = results.filter((r) => r.status === "fulfilled" && (r.value as Response).ok).length;
    const failed = results.length - sent;

    return new Response(JSON.stringify({ ok: failed === 0, sent, failed }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
