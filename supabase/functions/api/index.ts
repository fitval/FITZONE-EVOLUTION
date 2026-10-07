import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { clientAdmin } from "../_shared/securite.ts";
import { Acces, traiter } from "./routes.ts";

// API en lecture seule, une clé par athlète (docs/api.md). Appelée de serveur à serveur : pas de CORS.
// Déployée en --no-verify-jwt : la clé fzk_… n'est pas un jeton Supabase, l'appelant est vérifié ici (routes.ts).
// Chaque requête de ce fichier est filtrée sur le client_id de la clé : ne jamais en écrire une sans ce filtre.

const admin = clientAdmin();

const acces: Acces = {
  async trouverCle(prefix) {
    const { data } = await admin.from("api_keys").select("id, client_id, key_hash")
      .eq("prefix", prefix).is("revoked_at", null).maybeSingle();
    return data ? { id: String(data.id), client_id: String(data.client_id), key_hash: String(data.key_hash) } : null;
  },
  async utiliserCle(id) {
    const { data, error } = await admin.rpc("api_key_use", { p_id: id });
    if (error) throw error;
    return typeof data === "number" ? data : null;
  },
  depot: {
    async fiche(id) {
      const { data } = await admin.from("clients").select("id, first_name, start_date").eq("id", id).maybeSingle();
      return data;
    },
    async objectif(id) {
      const { data } = await admin.from("questionnaires").select("goal").eq("client_id", id)
        .order("submitted_at", { ascending: false }).limit(1);
      return data?.[0]?.goal ?? null;
    },
    // Même choix que l'app cliente : le programme visible le plus récent.
    async programmeEnCours(id) {
      const { data } = await admin.from("programs").select("id, nom, jours, created_at").eq("client_id", id)
        .eq("visible_client", true).order("created_at", { ascending: false }).limit(1);
      return data?.[0] ?? null;
    },
    async seances(id, du, au, offset, limit) {
      let q = admin.from("train_logs").select("id, date, session_name, exercises, comment, created_at", { count: "exact" })
        .eq("client_id", id);
      if (du) q = q.gte("date", du);
      if (au) q = q.lte("date", au);
      const { data, count, error } = await q.order("date", { ascending: false }).order("created_at", { ascending: false })
        .range(offset, offset + limit - 1);
      if (error) throw error;
      return { lignes: data ?? [], total: count ?? 0 };
    },
    async objectifsMacros(id) {
      const { data } = await admin.from("plans").select("kcal_target, protein_g, carb_g, fat_g, created_at")
        .eq("client_id", id).order("created_at", { ascending: false });
      return data ?? [];
    },
    async planAlimentaire(id) {
      const { data } = await admin.from("plans_full").select("id, jours, created_at").eq("client_id", id)
        .eq("visible_client", true).order("created_at", { ascending: false }).limit(1);
      return data?.[0] ?? null;
    },
    async pesees(id, du, au) {
      let q = admin.from("daily_logs").select("date, poids:data->Poids").eq("client_id", id);
      if (du) q = q.gte("date", du);
      if (au) q = q.lte("date", au);
      const { data } = await q.order("date", { ascending: false }).limit(2000);
      return data ?? [];
    },
  },
};

Deno.serve(async (req: Request) => {
  try {
    return await traiter(req, acces);
  } catch (e) {
    console.error("[api]", e instanceof Error ? e.message : e);
    return new Response(JSON.stringify({ error: "internal_error" }), {
      status: 500,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  }
});
