// Traduction des données de l'app vers le JSON publié par l'API (docs/api.md).
// Règle : un champ que l'app ne connaît pas vaut null, jamais une valeur inventée.
// Les noms des champs publiés sont fixés par le contrat de l'API : ne pas les renommer.

// deno-lint-ignore no-explicit-any
type Ligne = Record<string, any>;

const jour = (v: unknown): string | null => (v ? String(v).slice(0, 10) : null);
const iso = (v: unknown): string | null => (v ? new Date(String(v)).toISOString() : null);

// "80", "80,5", "80 kg" → 80.5 ; vide ou illisible → null
export function nombre(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v !== "string") return null;
  const n = parseFloat(v.replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

// "90s", "90", "2min", "1m30", "2'30" → secondes
export function secondes(v: unknown): number | null {
  if (typeof v === "number") return v;
  if (typeof v !== "string" || !v.trim()) return null;
  const s = v.trim().toLowerCase();
  const m = /^(\d+(?:[.,]\d+)?)\s*(?:min|mn|m|')\s*(\d+)?\s*(?:s|")?$/.exec(s);
  if (m) return Math.round(parseFloat(m[1].replace(",", ".")) * 60 + (m[2] ? parseInt(m[2]) : 0));
  const sec = /^(\d+)\s*(?:s|sec|")?$/.exec(s);
  return sec ? parseInt(sec[1]) : null;
}

const arrondi = (n: number) => Math.round(n);

// ── /me ─────────────────────────────────────────────────────────
export function formaterAthlete(fiche: Ligne, objectif: string | null) {
  return {
    athlete: {
      id: String(fiche.id),
      first_name: fiche.first_name ?? null,
      goal: objectif ?? null,
      coaching_since: jour(fiche.start_date),
    },
    updated_at: new Date().toISOString(),
  };
}

// ── /program ────────────────────────────────────────────────────
// Un programme de l'app est une suite de séances (Jour 1, Jour 2…), sans jour de semaine : `day` vaut donc null,
// et `day_index` (1, 2, …) donne l'ordre. Les supersets sont mis à plat (un exercice par ligne, même `superset`).
function repsDesSeries(ex: Ligne, series: Ligne[]): string | null {
  const brut = series.map((s) => String(s.reps ?? "").trim()).filter(Boolean);
  if (!brut.length) return ex.reps ? String(ex.reps) : null;
  const nums = brut.map(Number);
  if (nums.every(Number.isFinite)) {
    const min = Math.min(...nums), max = Math.max(...nums);
    return min === max ? String(min) : `${min}-${max}`;
  }
  return brut[0];
}

function exerciceProgramme(ex: Ligne, section: string, superset: string | null) {
  const series: Ligne[] = Array.isArray(ex.setsData) ? ex.setsData : [];
  const nbSeries = series.length || (nombre(ex.sets) ?? null);
  const s0 = series[0] ?? {};
  return {
    name: ex.nom ?? ex.label ?? null,
    sets: nbSeries,
    reps: repsDesSeries(ex, series),
    target_load_kg: null,
    target_rpe: null,
    target_rir: nombre(s0.rir),
    rest_seconds: secondes(s0.rest ?? (Array.isArray(ex.setsRest) ? ex.setsRest[0] : ex.setsRest)),
    notes: ex.notes ? String(ex.notes) : null,
    section,
    superset,
  };
}

export function formaterProgramme(p: Ligne | null) {
  if (!p) return { program: null, updated_at: null };
  const jours: Ligne[] = Array.isArray(p.jours) ? p.jours : [];
  let groupe = 0;
  const week = jours.map((d, i) => {
    const exercises: ReturnType<typeof exerciceProgramme>[] = [];
    for (const section of ["warmup", "workout", "cooldown"]) {
      for (const e of (Array.isArray(d[section]) ? d[section] : []) as Ligne[]) {
        if (e.superset && Array.isArray(e.exercises) && e.exercises.length) {
          const id = `ss${++groupe}`;
          for (const sub of e.exercises) exercises.push(exerciceProgramme(sub, section, id));
        } else {
          exercises.push(exerciceProgramme(e, section, null));
        }
      }
    }
    return { day: null, day_index: i + 1, session_name: d.nom ?? `Jour ${i + 1}`, exercises };
  });
  return {
    program: {
      id: String(p.id),
      name: p.nom ?? null,
      starts_on: null,
      ends_on: null,
      week,
    },
    updated_at: iso(p.created_at),
  };
}

// ── /sessions ───────────────────────────────────────────────────
// Une séance enregistrée dans l'app est une séance faite : status vaut toujours "done".
// L'app ne note pas de RPE par série (elle note un RIR) : rpe vaut null, rir est ajouté.
function serie(s: Ligne) {
  return {
    reps: nombre(s.reps ?? s.repsL),
    load_kg: nombre(s.kg ?? s.load ?? s.kgL),
    rpe: null,
    rir: nombre(s.rir ?? s.rirL),
  };
}

export function formaterSeance(t: Ligne) {
  const exos: Ligne[] = Array.isArray(t.exercises) ? t.exercises : [];
  const durees = exos.map((e) => nombre(e.duration_min)).filter((n): n is number => n !== null);
  return {
    id: String(t.id),
    date: jour(t.date),
    name: t.session_name ?? null,
    status: "done",
    duration_minutes: durees.length ? arrondi(durees.reduce((a, b) => a + b, 0)) : null,
    exercises: exos.map((e) => ({
      name: e.nom ?? null,
      sets: (Array.isArray(e.sets) ? e.sets : []).map(serie),
    })),
    athlete_notes: t.comment ? String(t.comment) : null,
    updated_at: iso(t.created_at),
  };
}

// ── /diet ───────────────────────────────────────────────────────
// Objectifs = calcul macros du coach (table plans, le plus récent fait foi, les autres = historique).
// Repas = premier menu (Jour 1) du plan alimentaire visible le plus récent ; les autres menus sont dans `days`.
// Les valeurs des aliments sont stockées pour 100 g, comme dans l'app cliente.
function cible(m: Ligne) {
  return {
    kcal: nombre(m.kcal_target),
    protein_g: nombre(m.protein_g),
    carbs_g: nombre(m.carb_g),
    fat_g: nombre(m.fat_g),
    effective_from: jour(m.created_at),
  };
}

function repas(r: Ligne) {
  const alims: Ligne[] = Array.isArray(r.items) ? r.items : Array.isArray(r.alims) ? r.alims : [];
  let k = 0, p = 0, c = 0, f = 0;
  for (const a of alims) {
    const q = (nombre(a.qte) ?? 100) / 100;
    k += (nombre(a.kcal) ?? 0) * q; p += (nombre(a.prot) ?? 0) * q;
    c += (nombre(a.carb) ?? 0) * q; f += (nombre(a.fat) ?? 0) * q;
  }
  return {
    name: r.nom ?? null,
    items: alims.map((a) => ({ food: a.nom ?? null, grams: nombre(a.qte) })),
    kcal: arrondi(k), protein_g: arrondi(p), carbs_g: arrondi(c), fat_g: arrondi(f),
    notes: r.note ? String(r.note) : null,
  };
}

export function formaterDiete(macros: Ligne[], plan: Ligne | null) {
  const [actuelle, ...anciennes] = macros;
  const jours: Ligne[] = plan && Array.isArray(plan.jours) ? plan.jours : [];
  const days = jours.map((d, i) => ({ name: d.nom ?? `Jour ${i + 1}`, meals: (Array.isArray(d.repas) ? d.repas : []).map(repas) }));
  const dates = [actuelle?.created_at, plan?.created_at].filter(Boolean).map((d) => new Date(d).getTime());
  return {
    targets: actuelle ? cible(actuelle) : null,
    history: anciennes.map((m) => {
      const { effective_from, ...reste } = cible(m);
      return { effective_from, ...reste };
    }),
    meals: days[0]?.meals ?? [],
    days,
    updated_at: dates.length ? new Date(Math.max(...dates)).toISOString() : null,
  };
}

// ── /bodyweight ─────────────────────────────────────────────────
// Le poids est saisi dans le suivi quotidien (daily_logs.data.Poids, en kg) : seul ce champ est lu, pas le reste du journal.
export function formaterPesees(logs: Ligne[]) {
  return {
    measurements: logs
      .map((l) => ({ date: jour(l.date), weight_kg: nombre(l.poids ?? l.data?.Poids) }))
      .filter((m) => m.date && m.weight_kg !== null)
      .sort((a, b) => String(b.date).localeCompare(String(a.date))),
  };
}
