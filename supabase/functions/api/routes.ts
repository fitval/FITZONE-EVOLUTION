// Routeur de l'API en lecture seule. Ne connaît la base qu'à travers `Acces` :
// index.ts branche la vraie base, les tests une base en mémoire.
import { egalTempsConstant, empreinte, lireCle } from "./cle.ts";
import { formaterAthlete, formaterDiete, formaterPesees, formaterProgramme, formaterSeance } from "./format.ts";

// deno-lint-ignore no-explicit-any
type Ligne = Record<string, any>;

export const LIMITE_PAR_MINUTE = 60;

// Toutes les lectures sont bornées à UNE athlète : clientId vient toujours de la clé, jamais de la requête.
export interface Depot {
  fiche(clientId: string): Promise<Ligne | null>;
  objectif(clientId: string): Promise<string | null>;
  programmeEnCours(clientId: string): Promise<Ligne | null>;
  seances(clientId: string, du: string | null, au: string | null, offset: number, limit: number): Promise<{ lignes: Ligne[]; total: number }>;
  objectifsMacros(clientId: string): Promise<Ligne[]>;
  planAlimentaire(clientId: string): Promise<Ligne | null>;
  pesees(clientId: string, du: string | null, au: string | null): Promise<Ligne[]>;
}

export interface Acces {
  // Ligne non révoquée portant ce préfixe, ou null.
  trouverCle(prefix: string): Promise<{ id: string; client_id: string; key_hash: string } | null>;
  // Note l'utilisation, renvoie le nombre d'appels de la minute (null = clé révoquée entre-temps).
  utiliserCle(id: string): Promise<number | null>;
  depot: Depot;
}

const json = (status: number, corps: unknown, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(corps), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...extra },
  });

const refus = () => json(401, { error: "unauthorized" });

const DATE = /^\d{4}-\d{2}-\d{2}$/;

function dateParam(url: URL, nom: string): string | null | undefined {
  const v = url.searchParams.get(nom);
  if (v === null || v === "") return null;
  return DATE.test(v) && !isNaN(Date.parse(v)) ? v : undefined;
}

function entierParam(url: URL, nom: string, defaut: number): number | undefined {
  const v = url.searchParams.get(nom);
  if (v === null || v === "") return defaut;
  return /^\d+$/.test(v) ? parseInt(v) : undefined;
}

// Le chemin reçu par la fonction est /api/v1/…, ou /functions/v1/api/v1/… selon l'environnement.
export function route(pathname: string): string | null {
  const m = /\/api(\/v1\/[a-z]+)\/?$/.exec(pathname);
  return m ? m[1] : null;
}

const ROUTES = ["/v1/me", "/v1/program", "/v1/sessions", "/v1/diet", "/v1/bodyweight"];

export async function traiter(req: Request, acces: Acces): Promise<Response> {
  const url = new URL(req.url);
  const r = route(url.pathname);

  // 1. Qui appelle ? Avant toute autre réponse : un inconnu n'apprend rien, pas même quelles routes existent.
  const lue = lireCle(req.headers.get("Authorization"));
  if (!lue) return refus();
  const ligne = await acces.trouverCle(lue.prefix);
  const attendue = ligne?.key_hash ?? "0".repeat(64);
  const ok = egalTempsConstant(await empreinte(lue.cle), attendue);
  if (!ligne || !ok) return refus();

  // 2. Lecture seule : tout autre verbe que GET est refusé, sur toutes les adresses.
  if (req.method !== "GET") {
    return json(405, { error: "method_not_allowed" }, { Allow: "GET" });
  }
  if (!r || !ROUTES.includes(r)) return json(404, { error: "not_found" });

  // 3. Débit.
  const n = await acces.utiliserCle(ligne.id);
  if (n === null) return refus();
  if (n > LIMITE_PAR_MINUTE) {
    return json(429, { error: "rate_limited" }, { "Retry-After": String(60 - new Date().getUTCSeconds()) });
  }

  const id = ligne.client_id;
  const d = acces.depot;

  switch (r) {
    case "/v1/me": {
      const fiche = await d.fiche(id);
      if (!fiche) return refus();
      return json(200, formaterAthlete(fiche, await d.objectif(id)));
    }
    case "/v1/program":
      return json(200, formaterProgramme(await d.programmeEnCours(id)));
    case "/v1/sessions": {
      const du = dateParam(url, "from"), au = dateParam(url, "to");
      const page = entierParam(url, "page", 1), limit = entierParam(url, "limit", 50);
      if (du === undefined || au === undefined || !page || !limit || page < 1 || limit < 1) {
        return json(400, { error: "bad_request" });
      }
      const lim = Math.min(limit, 100);
      const { lignes, total } = await d.seances(id, du, au, (page - 1) * lim, lim);
      return json(200, { sessions: lignes.map(formaterSeance), page, limit: lim, total });
    }
    case "/v1/diet":
      return json(200, formaterDiete(await d.objectifsMacros(id), await d.planAlimentaire(id)));
    case "/v1/bodyweight": {
      const du = dateParam(url, "from"), au = dateParam(url, "to");
      if (du === undefined || au === undefined) return json(400, { error: "bad_request" });
      return json(200, formaterPesees(await d.pesees(id, du, au)));
    }
  }
  return json(404, { error: "not_found" });
}
