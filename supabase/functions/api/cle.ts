// Clés d'API : format, empreinte, comparaison en temps constant.
// Une clé = fzk_<prefix>_<secret> : prefix (12 hex, non secret) retrouve la ligne, secret = 32 octets en base64url.
// La base ne garde que l'empreinte SHA-256 de la clé entière (migration 20261007120000_api_keys.sql).

const FORMAT = /^fzk_([0-9a-f]{12})_([A-Za-z0-9_-]{43})$/;

export function lireCle(entete: string | null): { cle: string; prefix: string } | null {
  const m = /^Bearer\s+(\S+)$/i.exec((entete ?? "").trim());
  if (!m) return null;
  const f = FORMAT.exec(m[1]);
  return f ? { cle: m[1], prefix: f[1] } : null;
}

export async function empreinte(cle: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(cle));
  return Array.from(new Uint8Array(h), (b) => b.toString(16).padStart(2, "0")).join("");
}

// Même durée quel que soit le premier caractère différent.
export function egalTempsConstant(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

// Utilisé par les tests (le dashboard a sa propre copie, côté navigateur).
export function nouvelleCle(): string {
  const hex = (n: number) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => b.toString(16).padStart(2, "0")).join("");
  const secret = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `fzk_${hex(6)}_${secret}`;
}
