/** Shared bits of the provider clients (Laravel Http facade semantics on top of fetch). */

/** PHP round(): half away from zero, with PHP's pre-rounding to 15 significant digits. */
export function phpRound(v: number): number {
  const pre = Number(Math.abs(v).toPrecision(15));
  return Math.sign(v) * Math.floor(pre + 0.5);
}

/** PHP rawurlencode() (RFC 3986). */
export const rawurlencode = (s: string): string =>
  encodeURIComponent(s).replace(/[!'()*]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase());

export const basic = (user: string, pass: string): string => 'Basic ' + Buffer.from(`${user}:${pass}`).toString('base64');

export interface HttpResult {
  ok: boolean;
  status: number;
  body: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  json: any;
}

/** One request with Laravel Http's 30 s default timeout; non-2xx does not throw (like Http::post). */
export async function request(url: string, init: RequestInit): Promise<HttpResult> {
  const res = await fetch(url, { ...init, signal: AbortSignal.timeout(30_000) });
  const body = await res.text();
  let json: unknown = null;
  try {
    json = JSON.parse(body);
  } catch {
    // non-JSON body → $res->json() is null
  }
  return { ok: res.ok, status: res.status, body, json };
}

export const env = (name: string, fallback = ''): string => process.env[name] ?? fallback;
