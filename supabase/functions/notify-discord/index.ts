import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Question = { id: string; label: string; type: string };

function truncate(s: string, n: number) {
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

function fmtAnswer(val: unknown): string {
  if (val == null) return "—";
  if (Array.isArray(val)) return val.length ? val.map(String).join(", ") : "—";
  if (typeof val === "object") return JSON.stringify(val);
  const s = String(val).trim();
  return s || "—";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const webhook = Deno.env.get("DISCORD_RECRUITMENT_WEBHOOK");
    if (!webhook) {
      return new Response(
        JSON.stringify({ error: "DISCORD_RECRUITMENT_WEBHOOK not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const formTitle: string = body.form_title || "Pré-diagnostic";
    const firstName: string = body.first_name || "";
    const lastName: string = body.last_name || "";
    const email: string = body.email || "";
    const phone: string = body.phone || "";
    const answers: Record<string, unknown> = body.answers || {};
    const questions: Question[] = Array.isArray(body.questions) ? body.questions : [];

    const fields: { name: string; value: string; inline?: boolean }[] = [];
    const fullName = `${firstName} ${lastName}`.trim() || "—";
    fields.push({ name: "👤 Candidat", value: truncate(fullName, 256), inline: true });
    if (email) fields.push({ name: "✉️ Email", value: truncate(email, 256), inline: true });
    if (phone) fields.push({ name: "📞 Téléphone", value: truncate(phone, 256), inline: true });

    // Up to ~20 question fields (Discord max = 25 fields per embed)
    const remainingSlots = 25 - fields.length;
    const pairs = questions.slice(0, remainingSlots).map((q) => ({
      name: truncate(q.label || q.id || "Question", 256),
      value: truncate(fmtAnswer(answers[q.id]), 1024),
      inline: false,
    }));
    fields.push(...pairs);

    const payload = {
      embeds: [
        {
          title: "📋 Nouveau pré-diagnostic complété",
          description: truncate(`**${formTitle}**`, 4096),
          color: 0xc49a2a,
          fields,
          timestamp: new Date().toISOString(),
          footer: { text: "FITZONE EVOLUTION" },
        },
      ],
    };

    const resp = await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      const txt = await resp.text();
      return new Response(
        JSON.stringify({ error: `Discord webhook failed: ${resp.status}`, detail: txt }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
