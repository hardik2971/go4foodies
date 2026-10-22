import { Router, type Request } from 'express';
import bcrypt from 'bcryptjs';
import { getAuth } from 'firebase-admin/auth';
import { C, first, get } from '../lib/db';
import { h, perm, requireAdmin, body } from '../lib/http';
import { HttpError } from '../lib/errors';
import { permissions } from '../lib/rbac';
import { currentUser } from '../lib/principal';
import * as V from '../lib/validation';
import { z } from 'zod';
import * as A from '../services/actions';
import * as Q from '../services/queries';

/**
 * Flutter Web admin API — one JSON endpoint per Laravel admin route (routes/admin/*.php), same
 * permission guards (`perm:` middleware) and the same Actions/Queries calls. Page GETs return
 * the data the Blade view received.
 */
const r = Router();

export const PAYMENT_METHODS = ['Cash', 'Credit Card', 'Debit Card', 'UPI', 'Wallet', 'Mixed'];

const str = (v: unknown) => (typeof v === 'string' ? v : v == null ? '' : String(v));
const optStr = (v: unknown) => (v === null || v === undefined ? undefined : str(v));
const num = (v: unknown) => Number(v);
const days = (req: Request, def: number) => ([1, 7, 30].includes(Number(req.query.days)) ? Number(req.query.days) : def);

/** Laravel `$request->validate()` helper for the small inline rule sets. */
function check<S extends z.ZodTypeAny>(schema: S, input: unknown): z.output<S> {
  return V.parse(schema, input);
}
const bool = z.boolean({ required_error: 'Required', invalid_type_error: 'Expected boolean' });

// ---- Auth (AuthController) ----

/**
 * Admin sign-in — same rules as the old Credentials login (email + password against the User table),
 * then a Firebase custom token so the Flutter app gets a Firebase Auth session (uid `user:<id>`).
 */
r.post('/auth/login', h(async (req) => {
  const { email, password } = check(z.object({ email: z.string().email('Invalid email or password.'), password: z.string().min(1, 'Invalid email or password.') }), body(req));
  const user = await first(C.users, 'emailLower', email.toLowerCase());
  const cred = user ? await get(C.credentials, `user_${user.id}`) : null;
  const hash = String(cred?.passwordHash ?? '').replace(/^\$2y\$/, '$2b$');
  if (!user || !hash || !bcrypt.compareSync(password, hash)) throw new HttpError(401, 'Invalid email or password.');
  const token = await getAuth().createCustomToken(`user:${user.id}`, {
    kind: 'user',
    refId: user.id,
    role: user.role,
    outletId: user.outletId ?? null,
    name: user.name,
    mail: user.email,
  });
  return { token, user: profile(user) };
}));

const profile = (u: { id: string; name?: string; email?: string; role?: string | null }) => ({
  id: u.id,
  name: u.name,
  email: u.email,
  role: u.role,
  permissions: permissions(u.role),
});

r.use(requireAdmin);

/** Layout data: signed-in user, permissions and the sidebar attention badge. */
r.get('/me', h(async () => {
  const me = currentUser()!;
  return { user: profile(me), attentionCount: await Q.getAttentionCount() };
}));

// ---- Dashboard ----

r.get('/dashboard', h(async () => {
  const [data, menuItems, categories, cfg] = await Promise.all([Q.getDashboardData(), Q.getMenuItems(), Q.getMenuCategories(), Q.getDashboardConfig()]);
  return {
    data,
    editable: permissions(currentUser()?.role).includes('manage:menu'),
    menuOptions: menuItems.map((m) => ({ id: m.id, name: m.name })),
    categoryOptions: categories.map((c) => c.name),
    currentItemId: cfg.trendingItemId,
  };
}));
r.post('/dashboard/trending', h(async (req) => {
  const { itemId } = check(z.object({ itemId: z.string().nullish() }), body(req));
  await A.setTrendingItem(itemId ?? null);
}));
r.post('/dashboard/top-categories', h(async (req) => {
  const { categories } = check(z.object({ categories: z.array(z.object({ name: z.string(), percent: z.coerce.number() })).nullish() }), body(req));
  await A.setTopCategories(categories ?? null);
}));

// ---- Orders ----

r.get('/orders', perm('manage:orders'), h(async () => ({ orders: await Q.getOrders() })));
r.patch('/orders/:id/status', perm('manage:orders'), h(async (req) => {
  const { status } = check(z.object({ status: z.enum(V.ORDER_STATUSES) }), body(req));
  await A.setOrderStatus(req.params.id, status);
}));

// ---- Menu ----

const menuInput = (b: Record<string, unknown>) => ({
  ...b,
  rating: b.rating ?? 0,
  tag: optStr(b.tag),
  available: b.available ?? true,
});
r.get('/menu', perm('manage:menu'), h(async () => ({ items: await Q.getMenuItems(), categories: await Q.getMenuCategories(), menuCategories: V.MENU_CATEGORIES })));
r.post('/menu/items', perm('manage:menu'), h(async (req) => {
  await A.createMenuItem(menuInput(body(req)));
  return { ok: true, items: await Q.getMenuItems(), categories: await Q.getMenuCategories() };
}));
r.put('/menu/items/:id', perm('manage:menu'), h(async (req) => { await A.updateMenuItem(req.params.id, menuInput(body(req))); }));
r.delete('/menu/items/:id', perm('manage:menu'), h(async (req) => { await A.deleteMenuItem(req.params.id); }));
r.patch('/menu/items/:id/availability', perm('manage:menu'), h(async (req) => {
  const { available } = check(z.object({ available: bool }), body(req));
  await A.setMenuAvailability(req.params.id, available);
}));
r.patch('/menu/categories/:id/active', perm('manage:menu'), h(async (req) => {
  const { active } = check(z.object({ active: bool }), body(req));
  await A.setCategoryActive(req.params.id, active);
}));

// ---- Reservations ----

r.get('/reservations', perm('manage:reservations'), h(async () => ({ reservations: await Q.getReservations() })));
r.patch('/reservations/:id/status', perm('manage:reservations'), h(async (req) => {
  const { status } = check(z.object({ status: z.enum(V.RESERVATION_STATUSES) }), body(req));
  await A.setReservationStatus(req.params.id, status);
}));
r.patch('/reservations/:id', perm('manage:reservations'), h(async (req) => {
  const b = body(req);
  const data = check(z.object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'The date field must match the format Y-m-d.').nullish().or(z.literal('')),
    time: z.string().nullish(),
    guests: z.coerce.number().int().min(1).optional(),
    occasion: z.string().nullish(),
    requests: z.string().nullish(),
  }), b);
  // Keep only the keys that were sent (ReservationEdit is a partial).
  const patch: Record<string, unknown> = {};
  for (const k of ['date', 'time', 'guests', 'occasion', 'requests'] as const) {
    if (k in b) patch[k] = k === 'guests' ? Math.trunc(Number(data.guests)) : (data[k] ?? '');
  }
  if (!patch.date) delete patch.date;
  await A.updateReservation(req.params.id, patch);
}));

// ---- Tables (QR) ----

const tableInput = (b: Record<string, unknown>) => ({ number: b.number, name: str(b.name), status: b.status ?? 'ACTIVE' });
r.get('/tables', perm('manage:tables'), h(async () => ({ tables: await Q.getTables(), websiteUrl: (process.env.WEBSITE_URL ?? '').replace(/\/+$/, '') })));
r.post('/tables', perm('manage:tables'), h(async (req) => ({ ok: true, table: await A.createTable(tableInput(body(req))) })));
r.put('/tables/:id', perm('manage:tables'), h(async (req) => { await A.updateTable(req.params.id, tableInput(body(req))); }));
r.patch('/tables/:id/status', perm('manage:tables'), h(async (req) => {
  const { status } = check(z.object({ status: z.enum(V.TABLE_STATUSES) }), body(req));
  await A.setTableStatus(req.params.id, status);
}));
r.delete('/tables/:id', perm('manage:tables'), h(async (req) => { await A.deleteTable(req.params.id); }));

// ---- Floor (live updates come from Firestore listeners on tables/tableSessions/orders) ----

const openInput = (b: Record<string, unknown>) => {
  const d = check(z.object({ customerCount: z.coerce.number().int().min(1), waiterId: z.string().nullish(), customerName: z.string().max(120).nullish() }), b);
  return { customerCount: d.customerCount, waiterId: d.waiterId || undefined, customerName: d.customerName || undefined };
};
const payMethod = (b: Record<string, unknown>) => check(z.object({ paymentMethod: z.string().max(50).nullish() }), b).paymentMethod ?? 'Cash';
const floorTables = () => Q.getFloorTables();

r.get('/floor', perm('manage:tables'), h(async () => ({ tables: await floorTables(), waiters: await Q.getWaiterOptions(), paymentMethods: PAYMENT_METHODS, states: V.TABLE_STATES })));
r.get('/floor/data', perm('manage:tables'), h(async () => ({ tables: await floorTables() })));
r.post('/floor/tables/:tableId/open', perm('manage:tables'), h(async (req) => {
  await A.openTableSession(req.params.tableId, openInput(body(req)));
  return { ok: true, tables: await floorTables() };
}));
r.post('/floor/sessions/:sessionId/close', perm('manage:tables'), h(async (req) => {
  await A.closeTableSession(req.params.sessionId, { paymentMethod: payMethod(body(req)) });
  return { ok: true, tables: await floorTables() };
}));
r.patch('/floor/tables/:tableId/state', perm('manage:tables'), h(async (req) => {
  const { state } = check(z.object({ state: z.enum(V.TABLE_STATES) }), body(req));
  await A.setTableState(req.params.tableId, state);
}));

// ---- POS ----

async function posPayload(tableId: string | undefined) {
  const pos = tableId ? await Q.getTablePos(tableId) : { table: null, session: null };
  return { ok: true, table: pos.table ?? null, session: pos.session ?? null, mergeTargets: tableId ? await Q.getMergeTargets(tableId) : [] };
}
const billingInput = (b: Record<string, unknown>) => {
  const d = check(z.object({ discount: z.coerce.number(), tax: z.coerce.number(), serviceCharge: z.coerce.number(), tip: z.coerce.number() }), b);
  return d;
};

r.get('/pos/:tableId', perm('manage:orders'), h(async (req) => {
  const pos = await Q.getTablePos(req.params.tableId);
  if (!pos.table) throw new HttpError(404, 'Not found');
  return {
    table: pos.table,
    session: pos.session ?? null,
    menu: await Q.getMenuItems(),
    waiters: await Q.getWaiterOptions(),
    mergeTargets: await Q.getMergeTargets(req.params.tableId),
    paymentMethods: PAYMENT_METHODS,
  };
}));
r.get('/pos/:tableId/data', perm('manage:orders'), h(async (req) => posPayload(req.params.tableId)));
r.post('/pos/:tableId/open', perm('manage:orders'), h(async (req) => {
  await A.openTableSession(req.params.tableId, openInput(body(req)));
  return posPayload(req.params.tableId);
}));
r.post('/pos/sessions/:sessionId/orders', perm('manage:orders'), h(async (req) => {
  const d = check(z.object({
    tableId: z.string().min(1),
    items: z.array(z.object({ menuItemId: z.string().min(1), qty: z.coerce.number().int().min(1) })).min(1),
  }), body(req));
  await A.addSessionOrder(req.params.sessionId, d.items);
  return posPayload(d.tableId);
}));
r.post('/pos/sessions/:sessionId/decrement', perm('manage:orders'), h(async (req) => {
  const d = check(z.object({ tableId: z.string().min(1), menuItemId: z.string().min(1) }), body(req));
  await A.decrementSessionItem(req.params.sessionId, d.menuItemId);
  return posPayload(d.tableId);
}));
r.patch('/pos/sessions/:sessionId/billing', perm('manage:orders'), h(async (req) => {
  await A.updateSessionBilling(req.params.sessionId, billingInput(body(req)));
  return posPayload(optStr(body(req).tableId));
}));
r.post('/pos/sessions/:sessionId/merge', perm('manage:orders'), h(async (req) => {
  const d = check(z.object({ tableId: z.string().min(1), fromSessionId: z.string().min(1) }), body(req));
  await A.mergeSessions(d.fromSessionId, req.params.sessionId);
  return posPayload(d.tableId);
}));
r.post('/pos/sessions/:sessionId/payments', perm('manage:orders'), h(async (req) => {
  const d = check(z.object({ tableId: z.string().min(1), amount: z.coerce.number().gt(0), method: z.string().min(1).max(50) }), body(req));
  await A.addPayment(req.params.sessionId, { amount: d.amount, method: d.method });
  return posPayload(d.tableId);
}));
r.post('/pos/sessions/:sessionId/close', perm('manage:orders'), h(async (req) => {
  const b = body(req);
  const billing = billingInput(b);
  const method = payMethod(b);
  await A.updateSessionBilling(req.params.sessionId, billing);
  await A.closeTableSession(req.params.sessionId, { paymentMethod: method });
  return { ok: true, redirect: '/floor' };
}));

// ---- Table analytics ----

r.get('/table-analytics', perm('view:reports'), h(async (req) => ({ data: await Q.getTableAnalytics(days(req, 1)) })));
r.get('/table-history/:tableId', perm('view:reports'), h(async (req) => {
  const d = days(req, 30);
  return { data: await Q.getTableHistory(req.params.tableId, d), days: d };
}));

// ---- Staff ----

const staffInput = (b: Record<string, unknown>) => ({
  name: b.name,
  email: b.email,
  phone: str(b.phone),
  password: str(b.password),
  role: b.role,
  active: b.active ?? true,
});
r.get('/staff', perm('manage:staff'), h(async () => ({ employees: await Q.getEmployees(), roles: V.STAFF_ROLES })));
r.post('/staff', perm('manage:staff'), h(async (req) => {
  await A.createStaff(staffInput(body(req)));
  return { ok: true, employees: await Q.getEmployees() };
}));
r.put('/staff/:id', perm('manage:staff'), h(async (req) => { await A.updateStaff(req.params.id, staffInput(body(req))); }));
r.patch('/staff/:id/status', perm('manage:staff'), h(async (req) => {
  const { status } = check(z.object({ status: z.enum(V.EMPLOYEE_STATUSES) }), body(req));
  await A.setEmployeeStatus(req.params.id, status);
}));
r.patch('/staff/:id/active', perm('manage:staff'), h(async (req) => {
  const { active } = check(z.object({ active: bool }), body(req));
  await A.setStaffActive(req.params.id, active);
}));
r.delete('/staff/:id', perm('manage:staff'), h(async (req) => { await A.deleteStaff(req.params.id); }));

// ---- Customers ----

const customerInput = (b: Record<string, unknown>) => ({ name: b.name, email: b.email, phone: str(b.phone), address: str(b.address), status: b.status ?? 'ACTIVE' });
r.get('/customers', perm('manage:customers'), h(async () => ({ customers: await Q.getCustomers() })));
r.post('/customers', perm('manage:customers'), h(async (req) => {
  await A.createCustomer(customerInput(body(req)));
  return { ok: true, customers: await Q.getCustomers() };
}));
r.put('/customers/:id', perm('manage:customers'), h(async (req) => { await A.updateCustomer(req.params.id, customerInput(body(req))); }));
r.delete('/customers/:id', perm('manage:customers'), h(async (req) => { await A.deleteCustomer(req.params.id); }));

// ---- Gift cards ----

r.get('/gift-cards', perm('manage:coupons'), h(async () => ({ cards: await Q.getGiftCards() })));
r.put('/gift-cards/:id', perm('manage:coupons'), h(async (req) => {
  const b = body(req);
  await A.updateGiftCard(req.params.id, { ...b, customerEmail: str(b.customerEmail), expiryDate: str(b.expiryDate) });
}));
r.patch('/gift-cards/:id/status', perm('manage:coupons'), h(async (req) => {
  const { status } = check(z.object({ status: z.enum(V.COUPON_STATUSES) }), body(req));
  await A.setGiftCardStatus(req.params.id, status);
}));
r.delete('/gift-cards/:id', perm('manage:coupons'), h(async (req) => { await A.deleteGiftCard(req.params.id); }));

// ---- Inventory ----

const inventoryInput = (b: Record<string, unknown>) => ({ ...b, supplier: str(b.supplier) });
r.get('/inventory', perm('manage:inventory'), h(async () => ({ items: await Q.getInventory(), categories: V.INVENTORY_CATEGORIES })));
r.post('/inventory', perm('manage:inventory'), h(async (req) => {
  await A.createInventoryItem(inventoryInput(body(req)));
  return { ok: true, items: await Q.getInventory() };
}));
r.put('/inventory/:id', perm('manage:inventory'), h(async (req) => { await A.updateInventoryItem(req.params.id, inventoryInput(body(req))); }));
r.patch('/inventory/:id/adjust', perm('manage:inventory'), h(async (req) => {
  const { delta } = check(z.object({ delta: z.coerce.number() }), body(req));
  await A.adjustInventory(req.params.id, num(delta));
}));
r.delete('/inventory/:id', perm('manage:inventory'), h(async (req) => { await A.deleteInventoryItem(req.params.id); }));

// ---- Read-only pages ----

r.get('/transactions', perm('view:reports'), h(async () => ({ transactions: await Q.getTransactions() })));
r.get('/reports', perm('view:reports'), h(async () => ({ data: await Q.getReportsData() })));
r.get('/outlets', perm('manage:outlets'), h(async () => ({ outlets: await Q.getOutlets() })));
r.get('/notifications', h(async () => ({ notifications: await Q.getNotifications() })));
r.get('/audit', perm('manage:settings'), h(async () => ({ logs: await Q.getAuditLogs(200) })));

// ---- Settings ----

r.get('/settings', perm('manage:settings'), h(async () => {
  const me = currentUser();
  return { profile: await Q.getProfile(), team: await Q.getUsers(), account: { name: me?.name ?? 'User', email: me?.email ?? '', role: me?.role ?? '' } };
}));
r.put('/settings/profile', perm('manage:settings'), h(async (req) => {
  const b = body(req);
  await A.updateProfile({ name: b.name, currency: b.currency, timezone: b.timezone, address: str(b.address), phone: str(b.phone), email: str(b.email) });
}));
r.post('/settings/password', perm('manage:settings'), h(async (req) => A.changePassword(body(req))));

export default r;
