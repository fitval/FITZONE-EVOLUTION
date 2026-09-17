// update-client-email
// Corrige l'email d'un client sur sa fiche ET sur son compte de connexion, sans jamais créer
// de second compte (corriger la fiche puis renvoyer l'invitation créait un compte orphelin).
//
// POST body: { client_id, email }
// Réservé au coach du client. Pas d'exception admin tant que coaches.role reste modifiable
// par n'importe quel compte connecté : sinon n'importe qui pourrait détourner un compte client.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { clientAdmin, exigerCoach, Refus, reponseRefus } from "../_shared/securite.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const EMAIL_VALIDE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // Réservé aux coachs connectés, vérifié avant même de lire la demande.
    const admin = clientAdmin();
    const { coachId } = await exigerCoach(req, admin);

    const body = await req.json();
    const clientId = typeof body.client_id === "string" ? body.client_id : "";
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    if (!clientId || !EMAIL_VALIDE.test(email)) {
      return json({ error: "client_id et email valide requis" }, 400);
    }

    const { data: client, error: lectureErr } = await admin
      .from("clients").select("id, coach_id, user_id, email").eq("id", clientId).maybeSingle();
    if (lectureErr) throw lectureErr;
    // Même réponse pour une fiche inexistante ou celle d'un autre coach.
    if (!client || client.coach_id !== coachId) {
      throw new Refus(403, "Client introuvable ou rattaché à un autre coach");
    }

    if (email === (client.email || "").trim().toLowerCase()) {
      return json({ ok: true, inchange: true });
    }

    // Pas encore de compte de connexion : seule la fiche porte l'email.
    if (!client.user_id) {
      const { error } = await admin.from("clients").update({ email }).eq("id", clientId);
      if (error) throw error;
      return json({ ok: true, compte_modifie: false, deja_connecte: false });
    }

    const { data: compte, error: compteErr } = await admin.auth.admin.getUserById(client.user_id);
    if (compteErr || !compte?.user) {
      return json({ error: "Compte de connexion introuvable pour cette fiche" }, 409);
    }
    const ancienEmailCompte = compte.user.email ?? "";

    // Compte d'abord : s'il refuse (adresse déjà prise), la fiche n'est pas touchée.
    const { error: majCompteErr } = await admin.auth.admin.updateUserById(client.user_id, {
      email, email_confirm: true,
    });
    if (majCompteErr) {
      const dejaPrise = /already|exists|registered|unique|duplicate/i.test(majCompteErr.message || "");
      return json(
        { error: dejaPrise ? "Cette adresse est déjà utilisée par un autre compte" : majCompteErr.message },
        dejaPrise ? 409 : 400,
      );
    }

    const { error: ficheErr } = await admin.from("clients").update({ email }).eq("id", clientId);
    if (ficheErr) {
      // Remet l'ancienne adresse sur le compte : jamais une fiche et un compte en désaccord.
      await admin.auth.admin.updateUserById(client.user_id, { email: ancienEmailCompte, email_confirm: true });
      throw ficheErr;
    }

    return json({ ok: true, compte_modifie: true, deja_connecte: !!compte.user.last_sign_in_at });
  } catch (err) {
    if (err instanceof Refus) return reponseRefus(err);
    return json({ error: (err as { message?: string }).message || "Erreur inconnue" }, 500);
  }
});
