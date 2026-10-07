// Tests de l'API en lecture seule, sur une base simulée en mémoire (aucune donnée réelle).
// Lancer : deno test supabase/functions/api/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { egalTempsConstant, empreinte, lireCle, nouvelleCle } from "./cle.ts";
import { secondes } from "./format.ts";
import { Acces, Depot, LIMITE_PAR_MINUTE, traiter } from "./routes.ts";

// deno-lint-ignore no-explicit-any
type Ligne = Record<string, any>;

// ── Base simulée : deux athlètes, A et B ─────────────────────────
const CLIENTS: Ligne[] = [
  { id: "A", first_name: "Athlète A", start_date: "2026-03-01", coach_notes: "privé A" },
  { id: "B", first_name: "Athlète B", start_date: "2026-01-10", coach_notes: "privé B" },
];
const PROGRAMMES: Ligne[] = [
  { id: 1, client_id: "A", visible_client: true, nom: "Prog A", created_at: "2026-09-14T08:00:00Z", jours: [
    { nom: "Pull A", workout: [
      { nom: "Tractions", setsData: [{ reps: "6", rest: "150s", rir: "2" }, { reps: "8", rest: "150s", rir: "2" }], notes: null },
      { superset: true, exercises: [{ nom: "Curl", setsData: [{ reps: "12", rest: "60s" }] }, { nom: "Face pull", sets: "3", reps: "15" }] },
    ] },
  ] },
  { id: 2, client_id: "B", visible_client: true, nom: "Prog B", created_at: "2026-09-20T08:00:00Z", jours: [] },
  { id: 3, client_id: "A", visible_client: false, nom: "Prog A caché", created_at: "2026-10-01T08:00:00Z", jours: [] },
];
const SEANCES: Ligne[] = [];
for (let i = 1; i <= 7; i++) {
  SEANCES.push({ id: i, client_id: "A", date: `2026-09-0${i}`, session_name: `Séance A${i}`, created_at: `2026-09-0${i}T10:00:00Z`,
    exercises: [{ nom: "Développé couché", sets: [{ reps: "6", kg: "80" }, { reps: "6", kg: "80,5" }] }], comment: null });
}
SEANCES.push({ id: 100, client_id: "B", date: "2026-09-03", session_name: "Séance B", created_at: "2026-09-03T10:00:00Z", exercises: [] });
const MACROS: Ligne[] = [
  { client_id: "A", kcal_target: 2586, protein_g: 190, carb_g: 333, fat_g: 52, created_at: "2026-09-16T08:00:00Z" },
  { client_id: "A", kcal_target: 2365, protein_g: 181, carb_g: 283, fat_g: 57, created_at: "2026-07-27T08:00:00Z" },
  { client_id: "B", kcal_target: 1800, protein_g: 120, carb_g: 200, fat_g: 60, created_at: "2026-09-01T08:00:00Z" },
];
const PLANS: Ligne[] = [
  { id: 10, client_id: "A", visible_client: true, created_at: "2026-09-16T08:00:00Z", jours: [
    { nom: "Jour 1", repas: [{ nom: "Repas 2", note: "Parmesan interdit", alims: [
      { nom: "Riz", qte: 110, kcal: 350, prot: 7, carb: 77, fat: 1 },
      { nom: "Poulet", qte: 150, kcal: 120, prot: 23, carb: 0, fat: 2 },
    ] }] },
  ] },
  { id: 11, client_id: "B", visible_client: true, created_at: "2026-09-20T08:00:00Z", jours: [{ nom: "Jour 1", repas: [{ nom: "Repas B", alims: [] }] }] },
];
const JOURNAUX: Ligne[] = [
  { client_id: "A", date: "2026-10-06", data: { Poids: 70.2, Stress: 3 } },
  { client_id: "A", date: "2026-10-05", data: { Stress: 2 } },
  { client_id: "B", date: "2026-10-06", data: { Poids: 55 } },
];

const depot: Depot = {
  fiche: async (id) => CLIENTS.find((c) => c.id === id) ?? null,
  objectif: async (id) => (id === "A" ? "Prise de masse" : "Perte de poids"),
  programmeEnCours: async (id) =>
    PROGRAMMES.filter((p) => p.client_id === id && p.visible_client).sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null,
  seances: async (id, du, au, offset, limit) => {
    const toutes = SEANCES.filter((s) => s.client_id === id && (!du || s.date >= du) && (!au || s.date <= au))
      .sort((a, b) => b.date.localeCompare(a.date));
    return { lignes: toutes.slice(offset, offset + limit), total: toutes.length };
  },
  objectifsMacros: async (id) => MACROS.filter((m) => m.client_id === id),
  planAlimentaire: async (id) => PLANS.find((p) => p.client_id === id && p.visible_client) ?? null,
  pesees: async (id, du, au) => JOURNAUX.filter((j) => j.client_id === id && (!du || j.date >= du) && (!au || j.date <= au)),
};

async function monter() {
  const cleA = nouvelleCle(), cleB = nouvelleCle(), cleRevoquee = nouvelleCle();
  const lignes = [
    { id: "kA", client_id: "A", prefix: lireCle(`Bearer ${cleA}`)!.prefix, key_hash: await empreinte(cleA), revoked: false, n: 0 },
    { id: "kB", client_id: "B", prefix: lireCle(`Bearer ${cleB}`)!.prefix, key_hash: await empreinte(cleB), revoked: false, n: 0 },
    { id: "kR", client_id: "A", prefix: lireCle(`Bearer ${cleRevoquee}`)!.prefix, key_hash: await empreinte(cleRevoquee), revoked: true, n: 0 },
  ];
  const acces: Acces = {
    trouverCle: async (prefix) => lignes.find((l) => l.prefix === prefix && !l.revoked) ?? null,
    utiliserCle: async (id) => {
      const l = lignes.find((x) => x.id === id && !x.revoked);
      return l ? ++l.n : null;
    },
    depot,
  };
  const appel = (chemin: string, cle?: string, method = "GET") =>
    traiter(new Request(`https://exemple.supabase.co/functions/v1/api${chemin}`, {
      method, headers: cle ? { Authorization: `Bearer ${cle}` } : {},
    }), acces);
  return { cleA, cleB, cleRevoquee, appel, lignes };
}

const ROUTES = ["/v1/me", "/v1/program", "/v1/sessions", "/v1/diet", "/v1/bodyweight"];

// ── Authentification ─────────────────────────────────────────────
Deno.test("sans clé → 401 sur chaque route", async () => {
  const { appel } = await monter();
  for (const r of ROUTES) {
    const res = await appel(r);
    assertEquals(res.status, 401, r);
    assertEquals(await res.json(), { error: "unauthorized" });
  }
});

Deno.test("clé inconnue, mal formée ou au mauvais secret → 401", async () => {
  const { appel, cleA } = await monter();
  assertEquals((await appel("/v1/me", nouvelleCle())).status, 401);
  assertEquals((await appel("/v1/me", "n_importe_quoi")).status, 401);
  const memePrefixeAutreSecret = cleA.slice(0, 18) + (cleA[18] === "A" ? "B" : "A") + cleA.slice(19);
  assertEquals((await appel("/v1/me", memePrefixeAutreSecret)).status, 401);
});

Deno.test("clé révoquée → 401", async () => {
  const { appel, cleRevoquee } = await monter();
  for (const r of ROUTES) assertEquals((await appel(r, cleRevoquee)).status, 401, r);
});

Deno.test("clé révoquée pendant l'appel → 401", async () => {
  const { appel, cleA, lignes } = await monter();
  assertEquals((await appel("/v1/me", cleA)).status, 200);
  lignes[0].revoked = true;
  assertEquals((await appel("/v1/me", cleA)).status, 401);
});

// ── Isolation ────────────────────────────────────────────────────
Deno.test("la clé de A ne voit jamais les données de B", async () => {
  const { appel, cleA } = await monter();
  const corps: string[] = [];
  for (const r of ROUTES) {
    const res = await appel(r, cleA);
    assertEquals(res.status, 200, r);
    corps.push(await res.text());
  }
  const tout = corps.join("\n");
  for (const marqueB of ["Athlète B", "Prog B", "Séance B", "1800", "Repas B", "55", "Perte de poids"]) {
    assert(!tout.includes(marqueB), `donnée de B visible : ${marqueB}`);
  }
  for (const prive of ["privé A", "privé B", "coach_notes", "Stress"]) assert(!tout.includes(prive), `fuite : ${prive}`);
  assert(!tout.includes("Prog A caché"), "programme masqué par le coach visible");
});

Deno.test("aucun paramètre ne permet de viser une autre athlète", async () => {
  const { appel, cleA } = await monter();
  const res = await appel("/v1/sessions?client_id=B&athlete=B&id=B", cleA);
  const { sessions } = await res.json();
  assert(sessions.every((s: Ligne) => s.name.startsWith("Séance A")));
});

// ── Lecture seule ────────────────────────────────────────────────
Deno.test("aucune route d'écriture sous /api/v1/", async () => {
  const { appel, cleA } = await monter();
  for (const r of [...ROUTES, "/v1/sessions/1", "/v1/keys"]) {
    for (const m of ["POST", "PUT", "PATCH", "DELETE"]) {
      const res = await appel(r, cleA, m);
      assertEquals(res.status, 405, `${m} ${r}`);
      assertEquals(res.headers.get("Allow"), "GET");
    }
  }
});

Deno.test("adresse inconnue → 404 (avec clé), 401 (sans)", async () => {
  const { appel, cleA } = await monter();
  assertEquals((await appel("/v1/clients", cleA)).status, 404);
  assertEquals((await appel("/v1/clients")).status, 401);
});

Deno.test("pas d'en-tête CORS", async () => {
  const { appel, cleA } = await monter();
  const res = await appel("/v1/me", cleA);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), null);
  assertEquals(res.headers.get("Content-Type"), "application/json; charset=utf-8");
});

// ── Débit ────────────────────────────────────────────────────────
Deno.test("au-delà de 60 requêtes par minute → 429", async () => {
  const { appel, cleA, cleB, lignes } = await monter();
  lignes[0].n = LIMITE_PAR_MINUTE - 1;
  assertEquals((await appel("/v1/me", cleA)).status, 200);
  const res = await appel("/v1/me", cleA);
  assertEquals(res.status, 429);
  assert(res.headers.get("Retry-After"));
  assertEquals((await appel("/v1/me", cleB)).status, 200, "la limite est par clé");
});

// ── Pagination ───────────────────────────────────────────────────
Deno.test("pagination de /sessions", async () => {
  const { appel, cleA } = await monter();
  const p1 = await (await appel("/v1/sessions?limit=3&page=1", cleA)).json();
  assertEquals([p1.page, p1.limit, p1.total, p1.sessions.length], [1, 3, 7, 3]);
  assertEquals(p1.sessions.map((s: Ligne) => s.date), ["2026-09-07", "2026-09-06", "2026-09-05"]);
  const p3 = await (await appel("/v1/sessions?limit=3&page=3", cleA)).json();
  assertEquals(p3.sessions.map((s: Ligne) => s.date), ["2026-09-01"]);
  const p4 = await (await appel("/v1/sessions?limit=3&page=4", cleA)).json();
  assertEquals(p4.sessions, []);
  const borne = await (await appel("/v1/sessions?from=2026-09-02&to=2026-09-04", cleA)).json();
  assertEquals(borne.total, 3);
  const max = await (await appel("/v1/sessions?limit=500", cleA)).json();
  assertEquals(max.limit, 100);
  for (const q of ["page=0", "limit=0", "page=x", "from=06-10-2026", "to=2026-13-45"]) {
    assertEquals((await appel(`/v1/sessions?${q}`, cleA)).status, 400, q);
  }
});

// ── Forme du JSON ────────────────────────────────────────────────
Deno.test("JSON publié : noms de champs et unités", async () => {
  const { appel, cleA } = await monter();
  const me = await (await appel("/v1/me", cleA)).json();
  assertEquals(me.athlete, { id: "A", first_name: "Athlète A", goal: "Prise de masse", coaching_since: "2026-03-01" });

  const { program } = await (await appel("/v1/program", cleA)).json();
  assertEquals(program.name, "Prog A");
  const [jour] = program.week;
  assertEquals([jour.day, jour.day_index, jour.session_name], [null, 1, "Pull A"]);
  assertEquals(jour.exercises[0], {
    name: "Tractions", sets: 2, reps: "6-8", target_load_kg: null, target_rpe: null, target_rir: 2,
    rest_seconds: 150, notes: null, section: "workout", superset: null,
  });
  assertEquals(jour.exercises.slice(1).map((e: Ligne) => [e.name, e.sets, e.reps, e.superset]), [["Curl", 1, "12", "ss1"], ["Face pull", 3, "15", "ss1"]]);

  const { sessions } = await (await appel("/v1/sessions", cleA)).json();
  assertEquals(sessions[0].status, "done");
  assertEquals(sessions[0].exercises[0].sets, [{ reps: 6, load_kg: 80, rpe: null, rir: null }, { reps: 6, load_kg: 80.5, rpe: null, rir: null }]);

  const diet = await (await appel("/v1/diet", cleA)).json();
  assertEquals(diet.targets, { kcal: 2586, protein_g: 190, carbs_g: 333, fat_g: 52, effective_from: "2026-09-16" });
  assertEquals(diet.history, [{ effective_from: "2026-07-27", kcal: 2365, protein_g: 181, carbs_g: 283, fat_g: 57 }]);
  assertEquals(diet.meals[0], {
    name: "Repas 2", items: [{ food: "Riz", grams: 110 }, { food: "Poulet", grams: 150 }],
    kcal: 565, protein_g: 42, carbs_g: 85, fat_g: 4, notes: "Parmesan interdit",
  });

  const bw = await (await appel("/v1/bodyweight?from=2026-09-01&to=2026-10-06", cleA)).json();
  assertEquals(bw, { measurements: [{ date: "2026-10-06", weight_kg: 70.2 }] });
});

// ── Briques ──────────────────────────────────────────────────────
Deno.test("format des clés et comparaison", async () => {
  const k = nouvelleCle();
  assert(lireCle(`Bearer ${k}`));
  assertEquals(lireCle(`Basic ${k}`), null);
  assertEquals((await empreinte(k)).length, 64);
  assert(egalTempsConstant("abc", "abc"));
  assert(!egalTempsConstant("abc", "abd"));
  assert(!egalTempsConstant("abc", "abcd"));
});

Deno.test("temps de repos", () => {
  assertEquals([secondes("90s"), secondes("90"), secondes("2min"), secondes("1m30"), secondes("2'30"), secondes("")], [90, 90, 120, 90, 150, null]);
});
