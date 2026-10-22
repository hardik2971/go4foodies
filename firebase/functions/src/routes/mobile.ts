import { Router, type Request, type RequestHandler, type Response } from 'express';
import bcrypt from 'bcryptjs';
import { DateTime } from 'luxon';
import { z, type ZodTypeAny } from 'zod';
import { C, all, create, db, def, get, iso, ms, now, ref, toDate, where, type Row } from '../lib/db';
import { Forbidden, HttpError, NotFound, ValidationError, type Issue } from '../lib/errors';
import { errorJson, mobileAuth } from '../lib/http';
import { sign } from '../lib/jwt';
import { runAs, type Principal } from '../lib/principal';
import { can, permissions } from '../lib/rbac';
import { nowLocal, round } from '../lib/format';
import * as V from '../lib/validation';
import * as A from '../services/actions';
import * as Q from '../services/queries';
import { placeOnlineOrder } from '../services/onlineOrder';
import { estimatePickup } from '../services/scheduling';
import { onlineOrderSchema } from '../services/zod';
import { jsonBody, type ApiResult } from '../services/json';
import * as Reservations from '../services/reservations';
import * as GiftCards from '../services/giftCards';

/**
 * Flutter app API — /api/mobile/* (routes/api/mobile.php). Same paths, methods, JSON, status codes,
 * error strings and HS256 JWT as the Laravel AuthController / CustomerController / StaffController,
 * dispatched through a port of MobileRouter (route table + RBAC) and MobileErrors (error → JSON).
 *
 * Cache-Control matches RawCacheControl: only successful router results and auth/me|password
 * carry `no-store`; errors, login/register and handler "raw" responses carry none.
 */
const r = Router();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Body = Record<string, any>;

// ---------------------------------------------------------------- errors (MobileErrors)

const DB_UNAVAILABLE = 'The restaurant database is unavailable. Please try again shortly.';

/** MobileErrors::respond — HttpError / ZodError / ValidationException / Forbidden / DB errors. */
export function mobileErrorJson(err: unknown): { status: number; body: Record<string, unknown> } {
  if (err instanceof z.ZodError) {
    return { status: 400, body: { error: err.issues[0]?.message ?? 'Invalid input', issues: err.issues } };
  }
  if (err instanceof ValidationError) return { status: 400, body: { error: err.issues[0]?.message ?? 'Invalid input', issues: err.issues } };
  // A missing row on update/delete (findOrFail → ModelNotFoundException, or an FK failure) was a 503.
  if (err instanceof NotFound || (err instanceof HttpError && err.status === 404 && err.message === 'Not found')) {
    console.error(err);
    return { status: 503, body: { error: DB_UNAVAILABLE } };
  }
  if (err instanceof HttpError) return { status: err.status, body: { error: err.message } };
  if (err instanceof Forbidden || (err instanceof Error && err.message === 'Forbidden')) {
    return { status: 403, body: { error: 'You do not have permission for this action' } };
  }
  return errorJson(err); // Firestore/gRPC → 503 DB_UNAVAILABLE; anything else → 500 {error: message || 'Server error'}
}

function sendError(res: Response, err: unknown): void {
  const { status, body } = mobileErrorJson(err);
  res.removeHeader('Cache-Control');
  res.status(status).json(body);
}

/** A handler-built response (Laravel Response returned as-is — no Cache-Control). */
class Raw implements ApiResult {
  constructor(public status: number, public body: unknown, public headers?: Record<string, string>) {}
}
const raw = (status: number, body: unknown, headers?: Record<string, string>) => new Raw(status, body, headers);
const fromApi = (r: ApiResult) => raw(r.status, r.body, r.headers);
const jsonError = (message: string, status: number, extra: Record<string, unknown> = {}) => raw(status, { error: message, ...extra });

function sendRaw(res: Response, out: Raw): void {
  res.removeHeader('Cache-Control'); // RawCacheControl: only an explicit intent survives
  if (out.headers) res.set(out.headers);
  res.status(out.status).json(out.body);
}

/** Z::parse — throws (→ 400 {error, issues}) keeping zod v3's full issue objects. */
function zparse<S extends ZodTypeAny>(schema: S, input: unknown): z.output<S> {
  const res = schema.safeParse(input);
  if (!res.success) throw new ValidationError(res.error.issues as unknown as Issue[]);
  return res.data;
}

/** Z::safeParse — [data, issues]. */
function zsafe<S extends ZodTypeAny>(schema: S, input: unknown): [z.output<S> | null, z.ZodIssue[]] {
  const res = schema.safeParse(input);
  return res.success ? [res.data, []] : [null, res.error.issues];
}

/** Body::object — always an object (`{}` when missing/invalid). */
const objBody = (req: Request): Body => {
  const j = jsonBody(req);
  return j && typeof j === 'object' ? (j as Body) : {};
};
const has = (o: object, k: string) => Object.prototype.hasOwnProperty.call(o, k);

/** PHP rawurldecode — %XX → bytes (UTF-8), malformed sequences left as-is, '+' untouched. */
function rawurldecode(s: string): string {
  if (!s.includes('%')) return s;
  try {
    return decodeURIComponent(s);
  } catch {
    const bytes: number[] = [];
    for (let i = 0; i < s.length; i++) {
      const m = s[i] === '%' ? /^[0-9a-f]{2}$/i.exec(s.slice(i + 1, i + 3)) : null;
      if (m) {
        bytes.push(parseInt(m[0], 16));
        i += 2;
      } else bytes.push(...Buffer.from(s[i], 'utf8'));
    }
    return Buffer.from(bytes).toString('utf8');
  }
}

// ---------------------------------------------------------------- MobileRouter

interface Ctx {
  user: Principal;
  params: Record<string, string>;
  req: Request;
  /** Parsed JSON body, `{}` when missing/invalid. */
  body: Body;
  /** URLSearchParams#get */
  query(key: string): string | null;
}
type RouteHandler = (ctx: Ctx) => unknown | Promise<unknown>;
const VERBS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

class MobileRouter {
  private routes: [string, string, string | null, RouteHandler][] = [];

  add(method: string, pattern: string, action: string | null, handler: RouteHandler): this {
    this.routes.push([method, pattern, action, handler]);
    return this;
  }

  private static match(pattern: string, segments: string[]): Record<string, string> | null {
    const parts = pattern.split('/');
    if (parts.length !== segments.length) return null;
    const params: Record<string, string> = {};
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      if (p.startsWith(':')) params[p.slice(1)] = rawurldecode(segments[i]);
      else if (p !== segments[i]) return null;
    }
    return params;
  }

  /**
   * Express handler for `<prefix>/{path}` (mounted under the prefix; Laravel's `.+` path). The
   * `mobile:<kinds>` auth only runs once the Laravel route itself matched (else → app 404).
   */
  handler(auth: RequestHandler): RequestHandler {
    return (req, res, next) => {
      // Laravel matches the decoded path with trailing slashes trimmed; an empty {path} is no route.
      const path = rawurldecode(req.path).replace(/^\//, '').replace(/\/+$/, '');
      if (!path || !VERBS.includes(req.method)) {
        next();
        return;
      }
      auth(req, res, (err?: unknown) => (err ? next(err) : void this.dispatch(req, res, path)));
    };
  }

  private async dispatch(req: Request, res: Response, path: string): Promise<void> {
    const user = req.principal!;
    const segments = path.split('/');
    {
      try {
        for (const [method, pattern, action, fn] of this.routes) {
          if (method !== req.method) continue;
          const params = MobileRouter.match(pattern, segments);
          if (params === null) continue;
          if (action && !can(user.role ?? null, action)) {
            sendRaw(res, jsonError('You do not have permission for this action', 403));
            return;
          }
          const ctx: Ctx = {
            user,
            params,
            req,
            body: objBody(req),
            query: (k) => (typeof req.query[k] === 'string' ? (req.query[k] as string) : null),
          };
          const result = await runAs(user, () => fn(ctx));
          if (result instanceof Raw) sendRaw(res, result);
          else {
            res.set('Cache-Control', 'no-store');
            res.json(result ?? { ok: true });
          }
          return;
        }
        sendRaw(res, jsonError('Not found', 404));
      } catch (e) {
        sendError(res, e);
      }
    }
  }
}

// ---------------------------------------------------------------- accounts (MobileUsers)

const INVALID = 'Invalid email or password';

/** Employee directory roles → RBAC role used by the Restaurant app. */
export const employeeRole = (role: string | null | undefined): string => (/manager|super admin/i.test(String(role ?? '')) ? 'MANAGER' : 'STAFF');

/** Profile returned by login / me — what the app renders and gates on. */
export async function mobileProfile(user: Principal): Promise<Record<string, unknown>> {
  const base = { id: user.id, name: user.name, email: user.email, kind: user.kind, role: user.role ?? null, permissions: permissions(user.role) };
  if (user.kind === 'customer') {
    const c = await get(C.customers, user.id);
    return { ...base, phone: c?.phone ?? '', address: c?.address ?? '' };
  }
  if (user.kind === 'employee') {
    const e = await get(C.employees, user.id);
    return { ...base, phone: e?.phone ?? '', title: e?.role ?? 'Staff', dutyStatus: e?.status ?? 'OFF' };
  }
  const title = user.role === 'OWNER' ? 'Owner' : user.role === 'MANAGER' ? 'Manager' : 'Staff';
  return { ...base, phone: '', title };
}

const customerSession = (c: Row): Principal => ({ id: c.id, name: c.name, email: c.email, role: null, outletId: null, kind: 'customer' });

/** `where('email', $email)->first()` on a utf8mb4_unicode_ci column → case-insensitive via emailLower. */
async function byEmail(coll: typeof C.customers | typeof C.users | typeof C.employees, email: string): Promise<Row | null> {
  const rows = await where(coll, 'emailLower', String(email).toLowerCase());
  if (!rows.length) return null;
  return rows.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))[0]; // InnoDB: primary-key order
}

async function passwordHash(kind: Principal['kind'], id: string): Promise<string | null> {
  const cred = await get(C.credentials, `${kind}_${id}`);
  return cred?.passwordHash ? String(cred.passwordHash) : null;
}

/** password_verify — $2a$/$2b$/$2y$ all verify (bcryptjs wants $2b$ for PHP's $2y$). */
function check(plain: string, hash: string | null | undefined): boolean {
  if (hash == null || hash === '') return false;
  try {
    return bcrypt.compareSync(plain, hash.replace(/^\$2y\$/, '$2b$'));
  } catch {
    return false;
  }
}

/** Run an auth handler: data → JSON (+ no-store when asked); Raw as-is; errors via MobileErrors. */
function authRoute(fn: (req: Request) => Promise<unknown>, opts: { noStore?: boolean; status?: number } = {}): RequestHandler {
  return async (req, res) => {
    try {
      const result = await runAs(req.principal ?? null, () => fn(req));
      if (result instanceof Raw) {
        sendRaw(res, result);
        return;
      }
      if (opts.noStore) res.set('Cache-Control', 'no-store');
      else res.removeHeader('Cache-Control');
      res.status(opts.status ?? 200).json(result);
    } catch (e) {
      sendError(res, e);
    }
  };
}

// ---------------------------------------------------------------- auth (AuthController)

const loginSchema = z.object({
  email: z.string().email('Enter a valid email'),
  password: z.string().min(1, 'Password is required'),
  app: z.enum(['customer', 'restaurant', 'owner']),
});

/** POST /api/mobile/auth/login — one endpoint, three apps (customer | restaurant | owner). */
r.post('/auth/login', authRoute(async (req) => {
  const { email, password, app } = zparse(loginSchema, jsonBody(req) ?? {});
  const fail = (msg = INVALID, status = 401) => jsonError(msg, status);
  let user: Principal;

  if (app === 'customer') {
    const c = await byEmail(C.customers, email);
    if (!c || !check(password, await passwordHash('customer', c.id))) return fail();
    if (c.status !== 'ACTIVE') return fail('This account is inactive. Please contact the restaurant.', 403);
    user = customerSession(c);
  } else {
    const u = await byEmail(C.users, email);
    if (u && check(password, await passwordHash('user', u.id))) {
      if (app === 'owner' && u.role !== 'OWNER') return fail('Owner access only. Use the Restaurant app.', 403);
      user = { id: u.id, name: u.name, email: u.email, role: u.role ?? null, outletId: u.outletId ?? null, kind: 'user' };
    } else if (app === 'restaurant') {
      const e = await byEmail(C.employees, email);
      if (!e || !check(password, await passwordHash('employee', e.id))) return fail();
      if (!e.active) return fail('Your staff account is inactive.', 403);
      user = { id: e.id, name: e.name, email: e.email ?? email, role: employeeRole(e.role), outletId: e.outletId ?? null, kind: 'employee' };
    } else {
      return fail();
    }
  }
  return { token: sign(user), user: await mobileProfile(user) };
}));

const registerSchema = z.object({
  name: z.string().trim().min(2, 'Name is required'),
  email: z.string().trim().toLowerCase().email('Enter a valid email'),
  phone: z.string().trim().min(5, 'Enter a valid phone number'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
});

/** POST /api/mobile/auth/register — Customer app sign-up (claims a guest Customer row). */
r.post('/auth/register', authRoute(async (req) => {
  const d = zparse(registerSchema, jsonBody(req) ?? {});
  const existing = await byEmail(C.customers, d.email);
  if (existing && (await passwordHash('customer', existing.id))) {
    return jsonError('An account with this email already exists. Please sign in.', 409);
  }
  const hash = A.hashPassword(d.password);
  let c: Row;
  if (existing) {
    await ref(C.customers, existing.id).update({ name: d.name, phone: d.phone, updatedAt: now() });
    await A.setCredentials('customer', existing.id, { email: existing.email, passwordHash: hash });
    c = { ...existing, name: d.name, phone: d.phone };
  } else {
    const t = now();
    const data = { name: d.name, email: d.email, emailLower: d.email.toLowerCase(), phone: d.phone, address: null, status: 'ACTIVE', createdAt: t, updatedAt: t };
    const id = await create(C.customers, data);
    await A.setCredentials('customer', id, { email: d.email, passwordHash: hash });
    c = { id, ...data };
  }
  const user = customerSession(c);
  return raw(201, { token: sign(user), user: await mobileProfile(user) });
}));

const me = mobileAuth('customer', 'user', 'employee');

/** GET /api/mobile/auth/me — current profile (+ permissions for staff apps). */
r.get('/auth/me', me, authRoute(async (req) => ({ user: await mobileProfile(req.principal!) }), { noStore: true }));

const optStr = z.string().trim().optional().or(z.literal(''));
const updateMeSchema = z.object({
  name: z.string().trim().min(2, 'Name is required'),
  phone: optStr,
  address: optStr,
});

/** Laravel DB::table()->where('id')->update() — a missing row is a silent no-op. */
async function updateIfExists(coll: typeof C.customers | typeof C.users | typeof C.employees, id: string, data: Record<string, unknown>): Promise<void> {
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref(coll, id));
    if (s.exists) tx.update(s.ref, data);
  });
}

/** PUT /api/mobile/auth/me — update own name / phone (/ address for customers). */
r.put('/auth/me', me, authRoute(async (req) => {
  const user = req.principal!;
  const d = zparse(updateMeSchema, jsonBody(req) ?? {});
  const phone = d.phone || null;
  if (user.kind === 'customer') {
    await updateIfExists(C.customers, user.id, { name: d.name, phone, address: d.address || null, updatedAt: now() });
  } else if (user.kind === 'employee') {
    await updateIfExists(C.employees, user.id, { name: d.name, phone });
  } else {
    await updateIfExists(C.users, user.id, { name: d.name, updatedAt: now() });
  }
  return { user: await mobileProfile({ ...user, name: d.name }) };
}, { noStore: true }));

const passwordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(6, 'New password must be at least 6 characters'),
});

/** POST /api/mobile/auth/password — change own password (any of the 3 apps). */
r.post('/auth/password', me, authRoute(async (req) => {
  const user = req.principal!;
  const d = zparse(passwordSchema, jsonBody(req) ?? {});
  const kind: Principal['kind'] = user.kind === 'customer' ? 'customer' : user.kind === 'employee' ? 'employee' : 'user';
  const current = await passwordHash(kind, user.id);
  if (!current || !check(d.currentPassword, current)) throw new HttpError(400, 'Current password is incorrect');
  await A.setCredentials(kind, user.id, { passwordHash: A.hashPassword(d.newPassword) });
  if (kind !== 'employee') await updateIfExists(kind === 'customer' ? C.customers : C.users, user.id, { updatedAt: now() });
  return { ok: true };
}, { noStore: true }));

// ---------------------------------------------------------------- shared public flows

const lower = (v: unknown) => (typeof v === 'string' ? v.toLowerCase() : v);
/** MySQL `col = ?` under utf8mb4_unicode_ci (case-insensitive). */
const ciEq = (a: unknown, b: unknown) => a != null && b != null && lower(a) === lower(b);

/** Reservation / gift-card flows are shared with the public website API (services/reservations, services/giftCards). */
const toRaw = (r: ApiResult) => raw(r.status, r.body, r.headers);
const createReservation = async (body: unknown) => toRaw(await Reservations.create(body));
const purchaseGiftCard = async (body: unknown) => toRaw(await GiftCards.purchase(body));

// ---------------------------------------------------------------- customer app (CustomerController)

const ACTIVE_ORDER = ['PENDING', 'PREPARING', 'READY'];

async function meCustomer(ctx: Ctx): Promise<Row> {
  const c = await get(C.customers, ctx.user.id);
  if (!c) throw new HttpError(401, 'Account not found');
  return c;
}

/** Orders placed in the app or earlier as a website guest with the same email. */
const mine = (ctx: Ctx) => (o: Row) => o.customerId === ctx.user.id || ciEq(o.customerEmail, ctx.user.email);
const ownsReservation = (ctx: Ctx) => (x: Row) => x.customerId === ctx.user.id || ciEq(x.email, ctx.user.email);
const byCreatedDesc = (a: Row, b: Row) => ms(b.createdAt) - ms(a.createdAt);

/** Accepts the Date / luxon DateTime / Carbon-like value scheduling.ts returns. */
function isoOf(v: unknown): string | undefined {
  if (v instanceof DateTime) return v.isValid ? v.toJSDate().toISOString() : undefined;
  return iso(v);
}

/** Orders (+ items + session.payments) → orderView[] in the given row order. */
async function orderViews(orders: Row[]): Promise<Record<string, unknown>[]> {
  if (!orders.length) return [];
  const sessionIds = [...new Set(orders.map((o) => o.sessionId).filter(Boolean))] as string[];
  const sessions = new Map((await Promise.all(sessionIds.map((id) => get(C.tableSessions, id)))).filter((s): s is Row => !!s).map((s) => [s.id, s]));
  const payments = sessionIds.length ? await where(C.payments, 'sessionId', sessionIds) : [];

  return orders.map((o) => {
    const s = o.sessionId ? sessions.get(o.sessionId) ?? null : null;
    let paid = 0;
    if (s) for (const p of payments) if (p.sessionId === s.id) paid += Number(p.amount);
    const createdAt = toDate(o.createdAt) ?? new Date(0);
    const scheduleDateIso = iso(o.scheduleDate);
    return def({
      id: o.id,
      number: o.number,
      type: o.type,
      status: o.status,
      channel: o.channel,
      total: Number(o.total),
      paid: o.paymentMethod === 'ONLINE' || !!o.razorpayPaymentId,
      paymentProvider: o.paymentProvider,
      scheduleType: o.scheduleType,
      scheduleDate: scheduleDateIso,
      scheduleTime: o.scheduleTime,
      estimatedPickup: o.type === 'PICKUP'
        ? isoOf(estimatePickup(o.scheduleType, scheduleDateIso ? scheduleDateIso.slice(0, 10) : null, o.scheduleTime ?? null, createdAt))
        : null,
      tableNumber: o.tableNumber,
      notes: o.notes,
      items: (o.items ?? []).map((i: Row) => ({ name: i.name, qty: Math.trunc(Number(i.qty)), price: Number(i.price) })),
      session: s ? {
        id: s.id,
        status: s.status,
        total: Number(s.total),
        paid,
        remaining: Math.max(0, round((Number(s.total) - paid) * 100) / 100),
      } : null,
      createdAt: createdAt.toISOString(),
    });
  });
}

/** Reservation → the Customer app view (`?? undefined` keys are dropped). */
export const reservationView = (x: Row) => def({
  id: x.id,
  reference: x.reference,
  kind: x.kind,
  status: x.status,
  date: iso(x.date),
  time: x.time,
  guests: x.guests == null ? null : Math.trunc(Number(x.guests)),
  occasion: x.occasion,
  requests: x.requests,
  eventType: x.eventType,
  guestRange: x.guestRange,
  space: x.space,
  company: x.company,
  message: x.message,
  createdAt: iso(x.createdAt),
});

const giftCardBodySchema = z.object({
  kind: z.enum(['GIFT_CARD', 'COUPON']).default('GIFT_CARD'),
  amount: z.coerce.number().positive(),
  message: z.string().max(500).optional(),
  payment: z.unknown().optional(),
});

const customer = new MobileRouter()
  // Home: restaurant info + live order / upcoming booking cards.
  .add('GET', 'home', null, async (ctx) => {
    const active = (await all(C.orders)).filter(mine(ctx)).filter((o) => ACTIVE_ORDER.includes(o.status)).sort(byCreatedDesc).slice(0, 5);
    // new Date(new Date().toDateString()) — today's local midnight
    const today = nowLocal().startOf('day').toMillis();
    const upcoming = (await all(C.reservations)).filter(ownsReservation(ctx))
      .filter((x) => ['REQUESTED', 'CONFIRMED'].includes(x.status) && ms(x.date) >= today)
      .sort((a, b) => ms(a.date) - ms(b.date)).slice(0, 3);
    return {
      profile: await Q.getProfile(),
      activeOrders: await orderViews(active),
      upcomingReservations: upcoming.map(reservationView),
    };
  })

  // ---- Orders ----
  .add('GET', 'orders', null, async (ctx) => {
    const rows = (await all(C.orders)).filter(mine(ctx)).sort(byCreatedDesc).slice(0, 100);
    return { orders: await orderViews(rows) };
  })
  .add('GET', 'orders/:id', null, async (ctx) => {
    const o = await get(C.orders, ctx.params.id);
    if (!o || !mine(ctx)(o)) throw new HttpError(404, 'Order not found');
    return { order: (await orderViews([o]))[0] };
  })
  // Place a Take Away or table (QR) order. `payAtRestaurant: true` skips the
  // online gateway; otherwise `payment` must carry a verified gateway result.
  .add('POST', 'orders', null, async (ctx) => {
    const c = await meCustomer(ctx);
    const b = ctx.body;
    const bodyPhone = b.phone ?? null;
    // PHP `[identity] + $body`: identity keys win.
    const [data, issues] = zsafe(onlineOrderSchema, { ...b, name: c.name, email: c.email, phone: c.phone || bodyPhone || '' });
    if (issues.length || !data) return jsonError(issues[0]?.message ?? 'Invalid order', 400, { issues });
    return fromApi(await placeOnlineOrder(data, (b.payAtRestaurant ?? null) === true));
  })

  // ---- Reservations ----
  .add('GET', 'reservations', null, async (ctx) => {
    const rows = (await all(C.reservations)).filter(ownsReservation(ctx)).sort((a, b) => ms(b.date) - ms(a.date));
    return { reservations: rows.map(reservationView) };
  })
  .add('POST', 'reservations', null, async (ctx) => {
    const c = await meCustomer(ctx);
    const b = ctx.body;
    return createReservation({ ...b, name: c.name, email: c.email, phone: c.phone || b.phone || '' });
  })
  .add('POST', 'reservations/:id/cancel', null, async (ctx) => {
    const x = await get(C.reservations, ctx.params.id);
    if (!x || !ownsReservation(ctx)(x)) throw new HttpError(404, 'Reservation not found');
    if (!['REQUESTED', 'CONFIRMED'].includes(x.status)) throw new HttpError(422, 'This booking can no longer be cancelled');
    const t = now();
    await ref(C.reservations, x.id).update({ status: 'CANCELED', updatedAt: t });
    return { reservation: reservationView({ ...x, status: 'CANCELED', updatedAt: t }) };
  })

  // ---- Gift cards ----
  .add('GET', 'gift-cards', null, async (ctx) => {
    const rows = (await all(C.giftCards)).filter((g) => g.customerId === ctx.user.id || ciEq(g.customerEmail, ctx.user.email)).sort(byCreatedDesc);
    return {
      giftCards: rows.map((g) => def({
        id: g.id,
        code: g.code,
        kind: g.kind,
        amount: Number(g.amount),
        message: g.message,
        status: g.status,
        paymentStatus: g.paymentStatus,
        expiryDate: iso(g.expiryDate),
        createdAt: iso(g.createdAt),
      })),
    };
  })
  .add('POST', 'gift-cards', null, async (ctx) => {
    const c = await meCustomer(ctx);
    const b = zparse(giftCardBodySchema, ctx.body);
    // The public flow links the card to the customer by email.
    return purchaseGiftCard({ ...b, name: c.name, email: c.email });
  })

  // ---- Table QR ----
  .add('GET', 'tables/:code', null, async (ctx) => {
    const t = (await where(C.tables, 'code', ctx.params.code)).find((x) => x.status === 'ACTIVE');
    if (!t) throw new HttpError(404, 'Table not found or not accepting orders');
    return { table: def({ id: t.id, number: t.number, name: t.name, code: t.code }) };
  });

// ---------------------------------------------------------------- staff apps (StaffController)

const ORDER_STATUSES = ['PENDING', 'PREPARING', 'READY', 'COMPLETED', 'CANCELED'] as const;
const RES_STATUSES = ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELED', 'NO_SHOW'] as const;
const TABLE_STATES = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'WAITING_PAYMENT', 'CLEANING', 'OUT_OF_SERVICE'] as const;
const DUTY = ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF'] as const;
const COUPON_STATUSES = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'] as const;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
/** Number(v ?? 0) || 0 */
const num = (v: unknown): number => Number(v ?? 0) || 0;
/** (int) Math.min(365, Math.max(1, Number(v) || d)) */
const days = (v: string | null, d: number): number => Math.trunc(Math.min(365, Math.max(1, Number(v) || d)));
const zenum = <T extends readonly [string, ...string[]]>(options: T, v: unknown): T[number] => zparse(z.enum(options), v);
const minStr = z.string().min(1);

async function sessionTable(sessionId: string): Promise<string> {
  const s = await get(C.tableSessions, sessionId);
  if (!s?.tableId) throw new HttpError(404, 'Session not found');
  return s.tableId;
}

/** Fresh POS view for a table — returned after every POS mutation. */
async function pos(tableId: string) {
  const data = await Q.getTablePos(tableId);
  if (!data.table) throw new HttpError(404, 'Table not found');
  const menu = (await Q.getMenuItems()).filter((m) => m.available);
  return { ...data, menu, mergeTargets: await Q.getMergeTargets(tableId), waiters: await Q.getWaiterOptions() };
}

const staff = new MobileRouter();

// ---- Overview ----
staff.add('GET', 'dashboard', 'view:dashboard', async () => {
  const dashboard = await Q.getDashboardData();
  const attention = await Q.getAttentionCount();
  const floor = await Q.getFloorTables();
  const count = (s: string) => floor.filter((t) => t.state === s).length;
  return {
    ...dashboard,
    attention,
    floor: {
      total: floor.length,
      available: count('AVAILABLE'),
      occupied: count('OCCUPIED'),
      reserved: count('RESERVED'),
      waitingPayment: count('WAITING_PAYMENT'),
      cleaning: count('CLEANING'),
    },
  };
});
staff.add('GET', 'notifications', 'view:dashboard', async () => ({ notifications: await Q.getNotifications() }));

// Own duty status (employees clock on/off from the Restaurant app).
staff.add('PATCH', 'me/duty', null, async (ctx) => {
  const status = zenum(DUTY, ctx.body.status);
  if (ctx.user.kind !== 'employee') throw new HttpError(422, 'Duty status applies to staff accounts');
  await updateIfExists(C.employees, ctx.user.id, { status });
  return { status };
});

// ---- Orders (kitchen / service board) ----
staff.add('GET', 'orders', 'manage:orders', async () => ({ orders: (await Q.getOrders()).slice(0, 300) }));
staff.add('PATCH', 'orders/:id/status', 'manage:orders', async (ctx) => {
  await A.setOrderStatus(ctx.params.id, zenum(ORDER_STATUSES, ctx.body.status));
  return { ok: true };
});

// ---- Floor plan & POS ----
staff.add('GET', 'floor', 'manage:orders', async () => ({ tables: await Q.getFloorTables(), waiters: await Q.getWaiterOptions() }));
staff.add('PATCH', 'tables/:id/state', 'operate:floor', async (ctx) => {
  await A.setTableState(ctx.params.id, zenum(TABLE_STATES, ctx.body.state));
  return { ok: true };
});
staff.add('GET', 'pos/:tableId', 'manage:orders', (ctx) => pos(ctx.params.tableId));
staff.add('POST', 'pos/:tableId/open', 'operate:floor', async (ctx) => {
  const b = ctx.body;
  const input: { customerCount: number; waiterId?: string; customerName?: string } = { customerCount: Math.max(1, num(b.customerCount)) };
  if (str(b.waiterId)) input.waiterId = str(b.waiterId);
  if (str(b.customerName)) input.customerName = str(b.customerName);
  await A.openTableSession(ctx.params.tableId, input);
  return pos(ctx.params.tableId);
});
const sessionItemsSchema = z.array(z.object({
  menuItemId: z.string().min(1),
  qty: z.coerce.number().int().min(1).max(50),
})).min(1);
staff.add('POST', 'sessions/:id/items', 'manage:orders', async (ctx) => {
  const items = zparse(sessionItemsSchema, ctx.body.items);
  await A.addSessionOrder(ctx.params.id, items);
  return pos(await sessionTable(ctx.params.id));
});
staff.add('POST', 'sessions/:id/void', 'manage:orders', async (ctx) => {
  await A.decrementSessionItem(ctx.params.id, zparse(minStr, ctx.body.menuItemId));
  return pos(await sessionTable(ctx.params.id));
});
staff.add('PUT', 'sessions/:id/billing', 'manage:orders', async (ctx) => {
  const b = ctx.body;
  await A.updateSessionBilling(ctx.params.id, { discount: num(b.discount), tax: num(b.tax), serviceCharge: num(b.serviceCharge), tip: num(b.tip) });
  return pos(await sessionTable(ctx.params.id));
});
staff.add('POST', 'sessions/:id/payments', 'manage:orders', async (ctx) => {
  const b = ctx.body;
  if (!(num(b.amount) > 0)) throw new HttpError(400, 'Enter an amount');
  await A.addPayment(ctx.params.id, { amount: num(b.amount), method: str(b.method) || 'Cash' });
  return pos(await sessionTable(ctx.params.id));
});
staff.add('POST', 'sessions/:id/close', 'operate:floor', async (ctx) => {
  const tableId = await sessionTable(ctx.params.id);
  const pm = str(ctx.body.paymentMethod);
  await A.closeTableSession(ctx.params.id, pm !== '' ? { paymentMethod: pm } : {});
  return pos(tableId);
});
staff.add('POST', 'sessions/:id/merge', 'manage:orders', async (ctx) => {
  const tableId = await sessionTable(ctx.params.id);
  // Merge THIS table's session into the chosen target session.
  const into = zparse(minStr, ctx.body.intoSessionId);
  await A.mergeSessions(ctx.params.id, into);
  return pos(tableId);
});

// ---- Tables (QR) ----
staff.add('GET', 'tables', 'manage:tables', async () => ({ tables: await Q.getTables(), websiteUrl: process.env.WEBSITE_URL ?? 'http://localhost:3000' }));
staff.add('POST', 'tables', 'manage:tables', async (ctx) => ({ table: await A.createTable(ctx.body) }));
staff.add('PUT', 'tables/:id', 'manage:tables', async (ctx) => {
  await A.updateTable(ctx.params.id, ctx.body);
  return { ok: true };
});
staff.add('DELETE', 'tables/:id', 'manage:tables', async (ctx) => {
  await A.deleteTable(ctx.params.id);
  return { ok: true };
});
staff.add('GET', 'table-analytics', 'view:reports', async (ctx) => ({ analytics: await Q.getTableAnalytics(days(ctx.query('days'), 1)) }));
staff.add('GET', 'table-history/:tableId', 'view:reports', async (ctx) => ({
  history: await Q.getTableHistory(ctx.params.tableId, days(ctx.query('days'), 30)),
}));

// ---- Reservations ----
staff.add('GET', 'reservations', 'manage:reservations', async () => ({ reservations: await Q.getReservations() }));
staff.add('PATCH', 'reservations/:id/status', 'manage:reservations', async (ctx) => {
  await A.setReservationStatus(ctx.params.id, zenum(RES_STATUSES, ctx.body.status));
  return { ok: true };
});
staff.add('PUT', 'reservations/:id', 'manage:reservations', async (ctx) => {
  const b = ctx.body;
  const input: { date?: string; time?: string; guests?: number; occasion?: string; requests?: string } = {};
  const d = str(b.date);
  if (d !== '') input.date = d;
  if (has(b, 'time')) input.time = str(b.time);
  if (has(b, 'guests')) input.guests = Math.max(1, num(b.guests));
  if (has(b, 'occasion')) input.occasion = str(b.occasion);
  if (has(b, 'requests')) input.requests = str(b.requests);
  await A.updateReservation(ctx.params.id, input);
  return { ok: true };
});

// ---- Menu ----
// Read access for anyone on the floor (item availability); edits need manage:menu.
staff.add('GET', 'menu', 'manage:orders', async () => ({ items: await Q.getMenuItems(), categories: await Q.getMenuCategories() }));
staff.add('POST', 'menu', 'manage:menu', async (ctx) => {
  await A.createMenuItem(ctx.body);
  return { ok: true };
});
staff.add('PUT', 'menu/:id', 'manage:menu', async (ctx) => {
  await A.updateMenuItem(ctx.params.id, ctx.body);
  return { ok: true };
});
staff.add('DELETE', 'menu/:id', 'manage:menu', async (ctx) => {
  await A.deleteMenuItem(ctx.params.id);
  return { ok: true };
});
staff.add('PATCH', 'menu/:id/availability', 'manage:menu', async (ctx) => {
  await A.setMenuAvailability(ctx.params.id, ctx.body.available === true);
  return { ok: true };
});
staff.add('PATCH', 'categories/:id', 'manage:menu', async (ctx) => {
  await A.setCategoryActive(ctx.params.id, ctx.body.active === true);
  return { ok: true };
});

// ---- Inventory ----
staff.add('GET', 'inventory', 'manage:inventory', async () => ({ items: await Q.getInventory() }));
staff.add('POST', 'inventory', 'manage:inventory', async (ctx) => {
  await A.createInventoryItem(ctx.body);
  return { ok: true };
});
staff.add('PUT', 'inventory/:id', 'manage:inventory', async (ctx) => {
  await A.updateInventoryItem(ctx.params.id, ctx.body);
  return { ok: true };
});
staff.add('POST', 'inventory/:id/adjust', 'manage:inventory', async (ctx) => {
  await A.adjustInventory(ctx.params.id, num(ctx.body.delta));
  return { ok: true };
});
staff.add('DELETE', 'inventory/:id', 'manage:inventory', async (ctx) => {
  await A.deleteInventoryItem(ctx.params.id);
  return { ok: true };
});

// ---- Staff ----
staff.add('GET', 'staff', 'manage:staff', async () => ({ employees: await Q.getEmployees(), roles: V.STAFF_ROLES }));
staff.add('POST', 'staff', 'manage:staff', async (ctx) => {
  await A.createStaff(ctx.body);
  return { ok: true };
});
staff.add('PUT', 'staff/:id', 'manage:staff', async (ctx) => {
  await A.updateStaff(ctx.params.id, ctx.body);
  return { ok: true };
});
staff.add('PATCH', 'staff/:id/status', 'manage:staff', async (ctx) => {
  await A.setEmployeeStatus(ctx.params.id, zenum(DUTY, ctx.body.status));
  return { ok: true };
});
staff.add('PATCH', 'staff/:id/active', 'manage:staff', async (ctx) => {
  await A.setStaffActive(ctx.params.id, ctx.body.active === true);
  return { ok: true };
});
staff.add('DELETE', 'staff/:id', 'manage:staff', async (ctx) => {
  await A.deleteStaff(ctx.params.id);
  return { ok: true };
});

// ---- Customers ----
staff.add('GET', 'customers', 'manage:customers', async () => ({ customers: await Q.getCustomers() }));
staff.add('POST', 'customers', 'manage:customers', async (ctx) => {
  await A.createCustomer(ctx.body);
  return { ok: true };
});
staff.add('PUT', 'customers/:id', 'manage:customers', async (ctx) => {
  await A.updateCustomer(ctx.params.id, ctx.body);
  return { ok: true };
});
staff.add('DELETE', 'customers/:id', 'manage:customers', async (ctx) => {
  await A.deleteCustomer(ctx.params.id);
  return { ok: true };
});

// ---- Gift cards & coupons ----
staff.add('GET', 'gift-cards', 'manage:coupons', async () => ({ giftCards: await Q.getGiftCards() }));
staff.add('PATCH', 'gift-cards/:id/status', 'manage:coupons', async (ctx) => {
  await A.setGiftCardStatus(ctx.params.id, zenum(COUPON_STATUSES, ctx.body.status));
  return { ok: true };
});
staff.add('DELETE', 'gift-cards/:id', 'manage:coupons', async (ctx) => {
  await A.deleteGiftCard(ctx.params.id);
  return { ok: true };
});

// ---- Reports & finance ----
staff.add('GET', 'reports', 'view:reports', async () => ({ reports: await Q.getReportsData() }));
staff.add('GET', 'transactions', 'view:reports', async () => ({ transactions: (await Q.getTransactions()).slice(0, 300) }));
staff.add('GET', 'outlets', 'manage:outlets', async () => ({ outlets: await Q.getOutlets() }));

// ---- Settings & audit (owner) ----
staff.add('GET', 'settings', 'manage:settings', async () => ({ profile: await Q.getProfile(), team: await Q.getUsers() }));
staff.add('PUT', 'settings', 'manage:settings', async (ctx) => {
  await A.updateProfile(ctx.body);
  return { profile: await Q.getProfile() };
});
staff.add('GET', 'audit', 'manage:settings', async (ctx) => {
  const limit = Number(ctx.query('limit') ?? null) || 150;
  return { logs: await Q.getAuditLogs(Math.trunc(Math.min(500, limit))) };
});

// ---------------------------------------------------------------- mount

r.use('/customer', customer.handler(mobileAuth('customer')));
r.use('/staff', staff.handler(mobileAuth('user', 'employee')));

export default r;
