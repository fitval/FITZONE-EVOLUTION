// Contrôle d'accès commun aux fonctions Edge.
// La plupart sont déployées en --no-verify-jwt, et même là où Supabase vérifie le jeton
// (send-client-email), il ne sait pas s'il s'agit d'un coach : c'est ICI que se vérifie l'appelant.
import { createClient, SupabaseClient, User } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function clesSecretes(): Record<string, string> {
  const brut = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!brut) throw new Error("SUPABASE_SECRET_KEYS absente");
  return JSON.parse(brut) as Record<string, string>;
}

// Client administrateur : nouvelle clé secrète, plus jamais SUPABASE_SERVICE_ROLE_KEY.
export function clientAdmin(): SupabaseClient {
  const cle = clesSecretes()["default"];
  if (!cle) throw new Error("Aucune clé secrète nommée 'default'");
  return createClient(Deno.env.get("SUPABASE_URL")!, cle, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export class Refus extends Error {
  status: 401 | 403;
  constructor(status: 401 | 403, message: string) {
    super(message);
    this.status = status;
  }
}

export function reponseRefus(e: Refus): Response {
  return new Response(JSON.stringify({ error: e.message }), {
    status: e.status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function utilisateur(req: Request, admin: SupabaseClient): Promise<User> {
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  // Une clé sb_… n'identifie personne : seul le jeton de session compte.
  if (!jwt || jwt.startsWith("sb_")) throw new Refus(401, "Connexion requise");
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) throw new Refus(401, "Session invalide");
  return data.user;
}

export async function exigerCoach(
  req: Request,
  admin: SupabaseClient,
  opts: { adminSeulement?: boolean } = {},
): Promise<{ user: User; coachId: string; role: string }> {
  const user = await utilisateur(req, admin);
  const { data: coach } = await admin.from("coaches").select("id, role").eq("user_id", user.id).maybeSingle();
  if (!coach) throw new Refus(403, "Réservé aux coachs");
  const role = String(coach.role ?? "");
  if (opts.adminSeulement && !["admin", "super_admin"].includes(role)) {
    throw new Refus(403, "Réservé aux administrateurs");
  }
  return { user, coachId: String(coach.id), role };
}

export async function exigerCompte(
  req: Request,
  admin: SupabaseClient,
): Promise<{ user: User; clientId: string | null; coachId: string | null }> {
  const user = await utilisateur(req, admin);
  const [{ data: cliente }, { data: coach }] = await Promise.all([
    admin.from("clients").select("id").eq("user_id", user.id).limit(1).maybeSingle(),
    admin.from("coaches").select("id").eq("user_id", user.id).maybeSingle(),
  ]);
  if (!cliente && !coach) throw new Refus(403, "Compte non reconnu");
  return { user, clientId: cliente ? String(cliente.id) : null, coachId: coach ? String(coach.id) : null };
}
