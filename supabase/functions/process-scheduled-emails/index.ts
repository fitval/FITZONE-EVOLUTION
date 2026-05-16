// process-scheduled-emails
// Cron worker — appelé toutes les heures par pg_cron.
//
// Pour chaque coach ayant des email_rules :
// - Règles type=scheduled : si weekday+hour correspond à l'heure
//   courante (Europe/Paris) et la condition (ex. pas de bilan cette
//   semaine) est remplie, envoie l'email à chaque client.
// - Règles type=random_weekly : choisit un créneau déterministe
//   dans la semaine ISO courante (seed = hash(coach_id+week_iso))
//   et envoie quand on l'a dépassé, une seule fois par semaine,
//   en piochant un message aléatoire dans le pool.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SENDER = "Fitzone Evolution <noreply@xn--fitzone-volution-iqb.fr>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Rule = {
  id: string;
  label?: string;
  enabled?: boolean;
  trigger: {
    type: "event" | "scheduled" | "random_weekly";
    event?: string;
    weekday?: number;
    hour?: number;
    condition?: string;
  };
  subject?: string;
  body?: string;
  messages?: { subject?: string; body: string }[];
};

type Client = { id: string; first_name: string; last_name: string; email: string | null };
type Coach = { id: string; first_name?: string; last_name?: string; gym?: string };

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
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
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: SENDER, to, subject, html }),
  });
  if (!res.ok) return { ok: false, error: `Resend ${res.status}: ${await res.text()}` };
  return { ok: true };
}

// Renvoie la date/heure courante dans le fuseau Europe/Paris.
function parisNow(): { date: Date; weekday: number; hour: number; minute: number } {
  const now = new Date();
  // Intl pour récupérer composantes Paris
  const fmt = new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Europe/Paris",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = fmt.formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value || "";
  const wdMap: Record<string, number> = { dim: 0, lun: 1, mar: 2, mer: 3, jeu: 4, ven: 5, sam: 6 };
  const wd = wdMap[get("weekday").toLowerCase().slice(0, 3)] ?? now.getUTCDay();
  const hour = parseInt(get("hour")) || 0;
  const minute = parseInt(get("minute")) || 0;
  return { date: now, weekday: wd, hour, minute };
}

// Calcule la semaine ISO (YYYY-Wnn) en se basant sur le lundi UTC.
function isoWeek(d: Date): string {
  const tmp = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((tmp.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${tmp.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

// Hash 32-bit déterministe pour seed (FNV-1a)
function hash32(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0;
  }
  return h >>> 0;
}

// Pour les règles random_weekly : créneau d'envoi dans la semaine.
// Renvoie Date de la prochaine fenêtre (Mar-Ven, 10h-17h Paris).
function randomWeeklySendDate(coachId: string, ruleId: string, weekIso: string, parisRefDate: Date): Date {
  const seed = hash32(`${coachId}|${ruleId}|${weekIso}`);
  const dayOffset = 1 + (seed % 4);       // 1=mardi, 2=mer, 3=jeu, 4=ven (à partir du lundi)
  const hour = 10 + ((seed >>> 4) % 8);   // 10..17
  // Lundi 00:00 Paris de cette semaine
  // parisRefDate est en heure machine, on retombe sur lundi local Paris
  const now = parisRefDate;
  // Calculer le lundi UTC qui correspond au lundi Paris : approximation
  // suffisante (+/- 1h, on s'aligne sur le créneau horaire)
  const utc = new Date(now.toISOString());
  const day = utc.getUTCDay() || 7; // 1..7 (lundi=1)
  const monday = new Date(utc);
  monday.setUTCDate(utc.getUTCDate() - (day - 1));
  monday.setUTCHours(0, 0, 0, 0);
  const sendAt = new Date(monday.getTime() + dayOffset * 86400000 + hour * 3600000);
  return sendAt;
}

async function alreadySent(supabase: SupabaseClient, params: { coachId: string; clientId: string | null; ruleId: string; weekIso: string }): Promise<boolean> {
  const { data } = await supabase
    .from("email_logs")
    .select("id")
    .eq("coach_id", params.coachId)
    .eq("rule_id", params.ruleId)
    .eq("week_iso", params.weekIso)
    .eq("client_id", params.clientId ?? null)
    .limit(1);
  return !!(data && data.length);
}

async function logSend(supabase: SupabaseClient, row: Record<string, unknown>) {
  // Best-effort. L'index unique prévient les doublons : on ignore les conflits.
  await supabase.from("email_logs").insert(row).then(() => {}, () => {});
}

async function processCoach(supabase: SupabaseClient, coach: Coach, rules: Rule[], paris: { date: Date; weekday: number; hour: number }, weekIso: string) {
  // Charge la liste des clients du coach une seule fois
  const { data: clientsData } = await supabase
    .from("clients")
    .select("id, first_name, last_name, email")
    .eq("coach_id", coach.id);
  const clients: Client[] = (clientsData || []).filter((c) => !!c.email);
  if (!clients.length) return { sent: 0, failed: 0 };

  let totalSent = 0;
  let totalFailed = 0;

  for (const rule of rules) {
    if (!rule || rule.enabled === false) continue;
    const t = rule.trigger?.type;

    if (t === "scheduled") {
      const weekday = rule.trigger?.weekday;
      const hour = rule.trigger?.hour;
      if (weekday == null || hour == null) continue;
      if (paris.weekday !== weekday || paris.hour !== hour) continue;

      // Si la condition est "no_bilan_this_week", on filtre par client
      let eligibleClients = clients;
      if (rule.trigger.condition === "no_bilan_this_week") {
        // Récupère tous les bilans du coach, déposés dans la semaine ISO courante
        const { data: bilans } = await supabase
          .from("bilans")
          .select("client_id, date")
          .eq("coach_id", coach.id);
        const submittedThisWeek = new Set<string>();
        (bilans || []).forEach((b) => {
          if (b.date && isoWeek(new Date(b.date)) === weekIso && b.client_id) {
            submittedThisWeek.add(b.client_id);
          }
        });
        eligibleClients = clients.filter((c) => !submittedThisWeek.has(c.id));
      }

      for (const c of eligibleClients) {
        if (await alreadySent(supabase, { coachId: coach.id, clientId: c.id, ruleId: rule.id, weekIso })) continue;
        const vars: Record<string, string> = {
          first_name: c.first_name || "",
          last_name: c.last_name || "",
          client_name: `${c.first_name || ""} ${c.last_name || ""}`.trim(),
          coach_name: `${coach.first_name || ""} ${coach.last_name || ""}`.trim() || "ton coach",
          coach_first_name: coach.first_name || "",
          gym: coach.gym || "Fitzone Evolution",
        };
        const subject = renderTemplate(rule.subject || "Un message de ton coach", vars);
        const body = renderTemplate(rule.body || "", vars);
        const res = await sendViaResend(c.email!, subject, wrapEmailHtml(body));
        await logSend(supabase, {
          coach_id: coach.id,
          client_id: c.id,
          rule_id: rule.id,
          event: "scheduled",
          week_iso: weekIso,
          email: c.email,
          subject,
          status: res.ok ? "sent" : "failed",
          error: res.error || null,
        });
        if (res.ok) totalSent++; else totalFailed++;
      }
    } else if (t === "random_weekly") {
      const pool = Array.isArray(rule.messages) ? rule.messages.filter((m) => m && m.body) : [];
      if (!pool.length) continue;
      const sendAt = randomWeeklySendDate(coach.id, rule.id, weekIso, paris.date);
      if (paris.date < sendAt) continue;

      // Une seule fois par semaine (par règle) — on log avec client_id=null comme marqueur
      if (await alreadySent(supabase, { coachId: coach.id, clientId: null, ruleId: rule.id, weekIso })) continue;

      // Choix aléatoire déterministe (basé sur la même seed)
      const seed = hash32(`${coach.id}|${rule.id}|${weekIso}|msg`);
      const msg = pool[seed % pool.length];

      // Log marqueur AVANT envoi pour bloquer les autres ticks concurrents
      await logSend(supabase, {
        coach_id: coach.id,
        client_id: null,
        rule_id: rule.id,
        event: "random_weekly",
        week_iso: weekIso,
        email: "(broadcast)",
        subject: msg.subject || rule.subject || "Des nouvelles de ton coach",
        status: "sent",
      });

      for (const c of clients) {
        const vars: Record<string, string> = {
          first_name: c.first_name || "",
          last_name: c.last_name || "",
          client_name: `${c.first_name || ""} ${c.last_name || ""}`.trim(),
          coach_name: `${coach.first_name || ""} ${coach.last_name || ""}`.trim() || "ton coach",
          coach_first_name: coach.first_name || "",
          gym: coach.gym || "Fitzone Evolution",
        };
        const subject = renderTemplate(msg.subject || rule.subject || "Des nouvelles de ton coach", vars);
        const body = renderTemplate(msg.body, vars);
        const res = await sendViaResend(c.email!, subject, wrapEmailHtml(body));
        await logSend(supabase, {
          coach_id: coach.id,
          client_id: c.id,
          rule_id: rule.id + ":delivery",
          event: "random_weekly",
          email: c.email,
          subject,
          status: res.ok ? "sent" : "failed",
          error: res.error || null,
        });
        if (res.ok) totalSent++; else totalFailed++;
      }
    }
  }

  return { sent: totalSent, failed: totalFailed };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const paris = parisNow();
    const weekIso = isoWeek(paris.date);

    // Charge tous les coaches ayant des règles email actives
    const { data: rows } = await supabase
      .from("settings")
      .select("coach_id, email_rules")
      .not("email_rules", "is", null);

    let totalSent = 0;
    let totalFailed = 0;
    const processed: { coach_id: string; sent: number; failed: number }[] = [];

    for (const row of rows || []) {
      const rules: Rule[] = Array.isArray(row.email_rules) ? row.email_rules : [];
      const activeRules = rules.filter((r) => r && r.enabled !== false &&
        (r.trigger?.type === "scheduled" || r.trigger?.type === "random_weekly"));
      if (!activeRules.length) continue;

      const { data: coach } = await supabase
        .from("coaches")
        .select("id, first_name, last_name, gym")
        .eq("id", row.coach_id)
        .maybeSingle();
      if (!coach) continue;

      const res = await processCoach(supabase, coach as Coach, activeRules, paris, weekIso);
      totalSent += res.sent;
      totalFailed += res.failed;
      processed.push({ coach_id: row.coach_id, sent: res.sent, failed: res.failed });
    }

    return new Response(JSON.stringify({
      ok: true,
      paris_weekday: paris.weekday,
      paris_hour: paris.hour,
      week_iso: weekIso,
      total_sent: totalSent,
      total_failed: totalFailed,
      processed,
    }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
