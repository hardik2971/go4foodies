import type { Request, Response } from 'express';

/**
 * Controller results — port of Api/Support/Json.php. The shared services (online orders,
 * reservations, gift cards) return a status + body instead of writing to `res`, so the website
 * routes and the mobile routes can both send them.
 */
export interface ApiResult {
  status: number;
  body: unknown;
  headers?: Record<string, string>;
}

export const response = (body: unknown, status = 200, headers?: Record<string, string>): ApiResult => ({ status, body, headers });

/** Same, with Cache-Control: no-store (most website-facing endpoints). */
export const noStore = (body: unknown, status = 200): ApiResult => response(body, status, { 'Cache-Control': 'no-store' });

export const error = (message: string, status: number, extra: Record<string, unknown> = {}): ApiResult => response({ error: message, ...extra }, status);

export function send(res: Response, r: ApiResult): void {
  if (r.headers) res.set(r.headers);
  res.status(r.status).json(r.body);
}

/** `new Response(text, {status})` — text/plain like the Web Response API. */
export function text(res: Response, body: string, status: number): void {
  res.status(status).setHeader('Content-Type', 'text/plain;charset=UTF-8');
  res.end(body);
}

/**
 * Body::json — `await req.json().catch(() => null)`: the decoded JSON, or null when the body is
 * missing / not JSON (express.json leaves `{}` when it didn't parse anything).
 */
export function jsonBody(req: Request): unknown {
  return (req as Request & { _body?: boolean })._body ? req.body : null;
}
