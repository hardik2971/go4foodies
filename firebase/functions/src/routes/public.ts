import { Router, type Request, type Response } from 'express';
import { C, db } from '../lib/db';
import { bearer, verify } from '../lib/jwt';
import { can } from '../lib/rbac';
import { error, jsonBody, noStore, response, send, text, type ApiResult } from '../services/json';
import { placeOnlineOrder } from '../services/onlineOrder';
import * as Reservations from '../services/reservations';
import { purchase } from '../services/giftCards';
import * as Razorpay from '../services/payments/razorpay';
import * as Stripe from '../services/payments/stripe';
import * as PayPal from '../services/payments/paypal';
import * as Uploads from '../services/uploads';
import { onlineOrderSchema, safeParse } from '../services/zod';

/**
 * Public website API — routes/api/public.php (same paths/JSON as the Next.js admin).
 * Not ported: the unauthenticated DirectoryController routes (GET/POST /customers, /staff,
 * /outlets) and GET /reservations, which leaked personal data, and /floor-stream (the admin
 * listens to Firestore instead).
 */
const r = Router();

/** Run a controller that returns an ApiResult. */
const ctl = (fn: (req: Request, res: Response) => Promise<ApiResult | void>) => async (req: Request, res: Response, next: (e?: unknown) => void) => {
  try {
    const out = await fn(req, res);
    if (out && !res.headersSent) send(res, out);
  } catch (e) {
    next(e);
  }
};

// Plain-object body like `is_array($body) ? $body : []`.
const obj = (b: unknown): Record<string, unknown> => (b && typeof b === 'object' ? (b as Record<string, unknown>) : {});

/** MySQL utf8mb4_unicode_ci ORDER BY. */
const collate = new Intl.Collator('en', { sensitivity: 'base' }).compare;

// GET /api/menu — public menu feed for the website (online ordering + QR menu).
r.get('/menu', ctl(async () => {
  try {
    // Only available items in active categories — disabled categories, hidden
    // and unavailable products never reach the storefront.
    const [items, cats] = await Promise.all([
      db.collection(C.menuItems).where('available', '==', true).get(),
      db.collection(C.categories).where('active', '==', true).get(),
    ]);
    const catName = new Map(cats.docs.map((c) => [c.id, String(c.get('name'))]));
    const rows = items.docs
      .filter((m) => catName.has(m.get('categoryId')))
      .map((m) => {
        const d = m.data();
        return {
          id: m.id,
          name: d.name,
          description: d.description ?? null,
          price: Number(d.price),
          rating: Number(d.rating),
          tag: d.tag ?? '',
          category: catName.get(d.categoryId)!,
          imageUrl: d.imageUrl ?? null,
        };
      })
      .sort((a, b) => collate(a.category, b.category) || collate(String(a.name), String(b.name)));
    const categories = [...new Set(rows.map((i) => i.category))];
    return noStore({ items: rows, categories });
  } catch (e) {
    console.error(e);
    return error('Menu unavailable', 503);
  }
}));

// POST /api/orders — the public website's online ordering flow (TAKE_AWAY | DINE_IN).
r.post('/orders', ctl(async (req) => {
  const [data, issues] = safeParse(onlineOrderSchema, jsonBody(req));
  if (!data) return error('Invalid order', 400, { issues });
  return placeOnlineOrder(data);
}));

r.post('/reservations', ctl((req) => Reservations.create(jsonBody(req))));
r.get('/reservations/availability', ctl((req) => Reservations.availability(req.query.date)));

// GET /api/tables/:code — resolves a scanned table QR code (ACTIVE tables only).
r.get('/tables/:code', ctl(async (req) => {
  try {
    const t = (await db.collection(C.tables).where('code', '==', req.params.code).get()).docs.find((d) => d.get('status') === 'ACTIVE');
    if (!t) return error('Table not found or inactive', 404);
    return noStore({ table: { id: t.id, number: t.get('number'), name: t.get('name') ?? null, code: t.get('code') } });
  } catch (e) {
    console.error(e);
    return error('Lookup failed', 503);
  }
}));

// GET /api/payment — which gateways are configured (drives the storefront chooser).
r.get('/payment', ctl(async () => noStore({ razorpay: Razorpay.configured(), stripe: Stripe.configured(), paypal: PayPal.configured() })));

// POST /api/payment — start a payment with the chosen provider.
r.post('/payment', ctl(async (req) => {
  const b = obj(jsonBody(req));
  const provider = b.provider === 'stripe' ? 'stripe' : b.provider === 'paypal' ? 'paypal' : 'razorpay';
  const amount = Number('amount' in b ? b.amount : undefined);
  const description = typeof b.description === 'string' ? b.description : 'Order payment';

  if (!(amount > 0)) return error('Invalid amount', 400);

  try {
    if (provider === 'stripe') {
      if (!Stripe.configured()) return error('Stripe not configured', 503);
      const intent = await Stripe.createPaymentIntent(amount, description);
      return noStore({ provider: 'stripe', publishableKey: Stripe.publishableKey(), clientSecret: intent.clientSecret });
    }
    if (provider === 'paypal') {
      if (!PayPal.configured()) return error('PayPal not configured', 503);
      const order = await PayPal.createOrder(amount, description);
      return noStore({ provider: 'paypal', clientId: PayPal.clientId(), orderId: order.orderId, currency: PayPal.currency() });
    }
    if (!Razorpay.configured()) return error('Razorpay not configured', 503);
    const order = await Razorpay.createOrder(amount, `rcpt_${Date.now()}`);
    return noStore({ provider: 'razorpay', keyId: Razorpay.keyId(), orderId: order.id, amount: order.amount, currency: order.currency });
  } catch (e) {
    console.error(e);
    return error('Could not start payment', 502);
  }
}));

// POST /api/payment/capture — capture an approved PayPal order.
r.post('/payment/capture', ctl(async (req) => {
  if (!PayPal.configured()) return error('PayPal not configured', 503);
  const b = obj(jsonBody(req));
  const orderId = typeof b.orderId === 'string' ? b.orderId : '';
  if (orderId === '') return error('Missing orderId', 400);
  try {
    const result = await PayPal.captureOrder(orderId);
    return noStore({ status: result.status });
  } catch (e) {
    console.error(e);
    return error('Could not capture payment', 502);
  }
}));

r.post('/gift-cards', ctl((req) => purchase(jsonBody(req))));

// GET /api/uploads/:name — public, path-traversal safe.
r.get('/uploads/:name', ctl(async (req, res) => {
  const name = req.params.name;
  if (!Uploads.validName(name)) return text(res, 'Bad request', 400);
  const f = await Uploads.find(name);
  if (!f) return text(res, 'Not found', 404);
  res.status(200).set({ 'Content-Type': Uploads.mimeFor(name), 'Cache-Control': 'public, max-age=31536000, immutable' });
  await new Promise<void>((resolve, reject) => {
    f.createReadStream().on('error', reject).on('end', resolve).pipe(res);
  });
}));

/**
 * POST /api/upload — multipart `file` (image ≤ 5MB) → {url} (absolute, from the request host).
 * Auth: admin web session, or a staff bearer token that may edit the menu (mobile app).
 */
r.post('/upload', ctl(async (req) => {
  if (!req.principal && !mobileMenuEditor(req)) return error('Unauthorized', 401);

  const raw = await rawBody(req);
  const file = Uploads.multipartFile(raw, req.header('content-type') ?? '', 'file');
  if (!file) return error('No file provided', 400);
  if (!file.contentType.startsWith('image/')) return error('Only image files are allowed', 415);
  if (file.data.length > Uploads.MAX_BYTES) return error('Image must be under 5MB', 413);

  let name: string;
  try {
    name = await Uploads.store(file.data, file.filename);
  } catch (e) {
    console.error(e);
    return error('Could not save image', 500);
  }
  const proto = (req.header('x-forwarded-proto') ?? req.protocol).split(',')[0].trim();
  const host = (req.header('x-forwarded-host') ?? req.header('host') ?? '').split(',')[0].trim();
  return response({ url: `${proto}://${host}/api/uploads/${name}` }, 201);
}));

function mobileMenuEditor(req: Request): boolean {
  const token = bearer(req.header('authorization'));
  if (!token) return false;
  try {
    const u = verify(token);
    return !!u && can(u.role, 'manage:menu');
  } catch {
    return false; // AUTH_SECRET not set
  }
}

/** The request bytes: Cloud Functions buffers them as req.rawBody; otherwise read the stream. */
async function rawBody(req: Request): Promise<Buffer> {
  const pre = (req as Request & { rawBody?: Buffer }).rawBody;
  if (pre) return pre;
  if (req.readableEnded) return Buffer.alloc(0);
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(Buffer.from(c));
  return Buffer.concat(chunks);
}

export default r;
