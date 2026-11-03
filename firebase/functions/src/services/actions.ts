import bcrypt from 'bcryptjs';
import { DateTime } from 'luxon';
import type { z } from 'zod';
import { C, db, ref, get, getOrFail, where, first, all, now, ts, toDate, type Row, type Coll } from '../lib/db';
import { cuid } from '../lib/cuid';
import { authorize, currentUser } from '../lib/principal';
import { HttpError } from '../lib/errors';
import { js, localTz, round } from '../lib/format';
import * as V from '../lib/validation';
import { sendMail } from './mailer';
import * as Mail from './emailTemplates';

/**
 * Write operations — port of Services/Actions.php (actions.ts). Every action authorizes with the
 * same RBAC action, validates with the same schemas and keeps the same side effects: audit log
 * entries, session total recomputation, transactions and the completion emails.
 * MySQL foreign keys (CASCADE / SET NULL / RESTRICT) are applied by hand — see 04-firestore-schema.md.
 */

// Record an audit-trail entry. Never throws — logging must not break an action.
export async function logAudit(action: string, entity: string, opts: { entityId?: string | null; detail?: string | null } = {}): Promise<void> {
  try {
    const u = currentUser();
    await ref(C.auditLogs, cuid()).set({
      action,
      entity,
      entityId: opts.entityId ?? null,
      detail: opts.detail ?? null,
      userId: u?.id ?? null,
      userName: u?.name ?? null,
      createdAt: now(),
    });
  } catch {
    // ignore
  }
}

/** Prisma-style update: always writes and bumps @updatedAt. */
async function save(coll: Coll, id: string, data: Record<string, unknown>, opts: { updatedAt?: boolean } = {}): Promise<void> {
  const r = ref(coll, id);
  const snap = await r.get();
  if (!snap.exists) throw new HttpError(404, 'Not found');
  await r.update(opts.updatedAt === false ? data : { ...data, updatedAt: now() });
}

/** JS `v || null`. */
const orNull = <T>(v: T): T | null => (v === undefined || v === null || (v as unknown) === '' || (v as unknown) === false || (v as unknown) === 0 ? null : v);

/** `new Date(s)`: date-only strings are UTC midnight, date-times are server-local. */
export function jsDate(s: string): Date {
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return new Date(s + 'T00:00:00.000Z');
  const dt = DateTime.fromISO(s, { zone: localTz() });
  return dt.isValid ? dt.toJSDate() : new Date(s);
}

/** bcryptjs-compatible hash (cost 10, "$2b$" prefix like the Node admin writes). */
export const hashPassword = (plain: string): string => bcrypt.hashSync(plain, 10);

/** Keep the locked credentials doc in step with the account. */
export async function setCredentials(kind: 'user' | 'employee' | 'customer', id: string, patch: { email?: string | null; passwordHash?: string | null }): Promise<void> {
  const data: Record<string, unknown> = { kind, refId: id };
  if (patch.email !== undefined) data.email = patch.email ? patch.email.toLowerCase() : null;
  if (patch.passwordHash !== undefined) data.passwordHash = patch.passwordHash;
  await ref(C.credentials, `${kind}_${id}`).set(data, { merge: true });
}

/** Set `field` to null on every doc of `coll` where `field == id` (FK ON DELETE SET NULL). */
async function nullify(coll: Coll, field: string, id: string): Promise<void> {
  const rows = await where(coll, field, id);
  const w = db.bulkWriter();
  for (const r of rows) w.update(ref(coll, r.id), { [field]: null });
  await w.close();
}

// ---- Menu ----

async function categoryId(name: string): Promise<string> {
  const existing = await first(C.categories, 'name', name);
  if (existing) return existing.id;
  const id = cuid();
  await db.runTransaction(async (tx) => {
    const q = await tx.get(db.collection(C.categories).where('name', '==', name).limit(1));
    if (q.empty) tx.create(ref(C.categories, id), { name, active: true });
  });
  return (await first(C.categories, 'name', name))!.id;
}

async function menuData(data: z.infer<typeof V.menuItemSchema>): Promise<Record<string, unknown>> {
  const row: Record<string, unknown> = {
    name: data.name,
    description: data.description,
    price: data.price,
    rating: data.rating,
    imageUrl: data.imageUrl,
    available: data.available,
    categoryId: await categoryId(data.category),
  };
  if (data.tag !== undefined) row.tag = data.tag; // undefined tag leaves the column untouched
  return row;
}

export async function createMenuItem(input: unknown): Promise<void> {
  authorize('manage:menu');
  const data = V.parse(V.menuItemSchema, input);
  const row = await menuData(data);
  await ref(C.menuItems, cuid()).create({ tag: null, outletId: null, ...row, createdAt: now(), updatedAt: now() });
}

export async function updateMenuItem(id: string, input: unknown): Promise<void> {
  authorize('manage:menu');
  const data = V.parse(V.menuItemSchema, input);
  await save(C.menuItems, id, await menuData(data));
}

export async function deleteMenuItem(id: string): Promise<void> {
  authorize('manage:menu');
  await getOrFail(C.menuItems, id);
  // OrderItem.menuItemId is ON DELETE RESTRICT: an item that was ever ordered can't be deleted.
  const orders = await all(C.orders);
  if (orders.some((o) => (o.items ?? []).some((it: Row) => it.menuItemId === id))) {
    throw new HttpError(409, 'This item has been ordered before and cannot be deleted. Mark it unavailable instead.');
  }
  await ref(C.menuItems, id).delete();
}

export async function setMenuAvailability(id: string, available: boolean): Promise<void> {
  authorize('manage:menu');
  await save(C.menuItems, id, { available });
}

// Enable/disable a whole category — disabled categories (and their items) are hidden from the storefront.
export async function setCategoryActive(id: string, active: boolean): Promise<void> {
  authorize('manage:menu');
  await save(C.categories, id, { active }, { updatedAt: false });
}

// ---- Floor plan / table sessions ----

export async function openTableSession(tableId: string, input: { customerCount?: unknown; waiterId?: string | null; customerName?: string | null }): Promise<void> {
  authorize('operate:floor');
  const count = input.customerCount ?? 0;
  const opened = await db.runTransaction(async (tx) => {
    const open = await tx.get(db.collection(C.tableSessions).where('tableId', '==', tableId).where('status', '==', 'OPEN').limit(1));
    if (!open.empty) return false; // already occupied — no-op
    const table = await tx.get(ref(C.tables, tableId));
    if (!table.exists) throw new HttpError(404, 'Not found');
    const t = now();
    tx.create(ref(C.tableSessions, cuid()), {
      ...sessionDefaults(),
      tableId,
      status: 'OPEN',
      openedAt: t,
      customerCount: Math.max(1, Math.trunc(Number(count)) || 0),
      waiterId: orNull(input.waiterId ?? null),
      customerName: orNull(input.customerName ?? null),
      createdAt: t,
      updatedAt: t,
    });
    tx.update(ref(C.tables, tableId), { state: 'OCCUPIED', updatedAt: t });
    return true;
  });
  if (opened) await logAudit('session.open', 'TableSession', { entityId: tableId, detail: `${isFinite(Number(count)) ? js(Number(count)) : String(count)} guests` });
}

export const sessionDefaults = () => ({
  closedAt: null,
  customerCount: 1,
  customerName: null,
  customerId: null,
  waiterId: null,
  notes: null,
  subtotal: 0,
  discount: 0,
  tax: 0,
  serviceCharge: 0,
  tip: 0,
  total: 0,
  paymentMethod: null,
  paymentStatus: null,
});

// Recompute a session's subtotal from its orders and the total from the stored adjustments.
export async function recomputeSessionTotals(sessionId: string): Promise<void> {
  const s = await get(C.tableSessions, sessionId);
  if (!s) return;
  const orders = await where(C.orders, 'sessionId', sessionId);
  const subtotal = orders.reduce((sum, o) => sum + Number(o.total), 0);
  const total = subtotal - Number(s.discount) + Number(s.tax) + Number(s.serviceCharge) + Number(s.tip);
  await ref(C.tableSessions, sessionId).update({ subtotal, total: Math.max(0, total), updatedAt: now() });
}

/** Add items to an open table session (POS waiter entry) — a DINE_IN POS order linked to the session. */
export async function addSessionOrder(sessionId: string, items: { menuItemId: string; qty: unknown }[]): Promise<void> {
  authorize('manage:orders');
  if (!items?.length) return;
  const session = await get(C.tableSessions, sessionId);
  if (!session || session.status === 'CLOSED') throw new HttpError(500, 'Session is closed');
  const table = await get(C.tables, session.tableId);

  const snaps = await db.getAll(...[...new Set(items.map((i) => i.menuItemId))].map((id) => ref(C.menuItems, id)));
  const byId = new Map(snaps.filter((s) => s.exists).map((s) => [s.id, { id: s.id, ...s.data() } as Row]));
  const lines = items.map((i) => {
    const mi = byId.get(i.menuItemId);
    if (!mi) throw new HttpError(500, 'Item not found');
    return { id: cuid(), menuItemId: mi.id, name: mi.name, qty: Math.trunc(Number(i.qty)), price: Number(mi.price) };
  });
  const total = lines.reduce((s, l) => s + l.price * l.qty, 0);
  const outlet = (await db.collection(C.outlets).limit(1).get()).docs[0];
  const t = now();
  await ref(C.orders, cuid()).create({
    ...orderDefaults(),
    number: await uniqueOrderNumber(),
    type: 'DINE_IN',
    status: 'PENDING',
    channel: 'POS',
    scheduleType: 'NOW',
    total,
    outletId: outlet?.id ?? 'pos',
    customerName: session.customerName ?? `Table ${table?.number}`,
    tableId: session.tableId,
    tableNumber: table?.number ?? null,
    sessionId: session.id,
    items: lines,
    createdAt: t,
    updatedAt: t,
  });
  await recomputeSessionTotals(session.id);
  await logAudit('order.add', 'Order', { entityId: session.id, detail: `${items.length} item(s)` });
}

export const orderDefaults = () => ({
  paymentMethod: null,
  customerId: null,
  customerEmail: null,
  customerPhone: null,
  notes: null,
  scheduleDate: null,
  scheduleTime: null,
  scheduleType: 'NOW',
  tableId: null,
  tableNumber: null,
  sessionId: null,
  razorpayPaymentId: null,
  paymentProvider: null,
});

/** 'ORD-' + random 5 digits, unique (Order.number is a unique key). */
export async function uniqueOrderNumber(): Promise<string> {
  for (;;) {
    const n = 'ORD-' + (10000 + Math.floor(Math.random() * 90000));
    if (!(await first(C.orders, 'number', n))) return n;
  }
}

export async function updateSessionBilling(sessionId: string, b: { discount?: unknown; tax?: unknown; serviceCharge?: unknown; tip?: unknown }): Promise<void> {
  authorize('manage:orders');
  const n = (v: unknown) => Math.max(0, Number(v ?? 0) || 0);
  await save(C.tableSessions, sessionId, { discount: n(b.discount), tax: n(b.tax), serviceCharge: n(b.serviceCharge), tip: n(b.tip) });
  await recomputeSessionTotals(sessionId);
}

// Remove one unit of an item from the session bill (void) — from the most recent order containing it.
export async function decrementSessionItem(sessionId: string, menuItemId: string): Promise<void> {
  authorize('manage:orders');
  const orders = (await where(C.orders, 'sessionId', sessionId)).sort((a, b) => toDate(b.createdAt)!.getTime() - toDate(a.createdAt)!.getTime());
  const order = orders.find((o) => (o.items ?? []).some((it: Row) => it.menuItemId === menuItemId));
  if (!order) return;
  const items: Row[] = [...order.items];
  const idx = items.findIndex((it) => it.menuItemId === menuItemId);
  if (items[idx].qty > 1) items[idx] = { ...items[idx], qty: items[idx].qty - 1 };
  else items.splice(idx, 1);
  if (!items.length) await ref(C.orders, order.id).delete();
  else await ref(C.orders, order.id).update({ items, total: items.reduce((s, it) => s + Number(it.price) * Number(it.qty), 0), updatedAt: now() });
  await recomputeSessionTotals(sessionId);
  await logAudit('order.void', 'Order', { entityId: sessionId, detail: 'Removed item' });
}

// Merge one open session's orders + payments into another, then free the source table.
export async function mergeSessions(fromSessionId: string, intoSessionId: string): Promise<void> {
  authorize('manage:orders');
  if (fromSessionId === intoSessionId) return;
  const from = await get(C.tableSessions, fromSessionId);
  const into = await get(C.tableSessions, intoSessionId);
  if (!from || !into || from.status === 'CLOSED' || into.status === 'CLOSED') return;
  const w = db.bulkWriter();
  for (const o of await where(C.orders, 'sessionId', fromSessionId)) w.update(ref(C.orders, o.id), { sessionId: intoSessionId });
  for (const p of await where(C.payments, 'sessionId', fromSessionId)) w.update(ref(C.payments, p.id), { sessionId: intoSessionId });
  await w.close();
  const t = now();
  await ref(C.tableSessions, intoSessionId).update({ customerCount: Number(into.customerCount) + Number(from.customerCount), updatedAt: t });
  await ref(C.tableSessions, fromSessionId).update({ status: 'CLOSED', closedAt: t, notes: `Merged into table ${into.tableId}`, updatedAt: t });
  await save(C.tables, from.tableId, { state: 'CLEANING' });
  await recomputeSessionTotals(intoSessionId);
  await logAudit('session.merge', 'TableSession', { entityId: intoSessionId, detail: `Merged from ${from.tableId}` });
}

/** Record a partial payment against a session (split bills / mixed tender). */
export async function addPayment(sessionId: string, input: { amount?: unknown; method: string }): Promise<void> {
  authorize('manage:orders');
  const amount = Number(input.amount);
  if (!(input.amount !== null && input.amount !== '' && isFinite(amount) && amount > 0)) return;
  if (!(await get(C.tableSessions, sessionId))) throw new HttpError(404, 'Not found'); // FK
  await ref(C.payments, cuid()).create({ sessionId, amount, method: input.method, createdAt: now() });
  await logAudit('payment.add', 'Payment', { entityId: sessionId, detail: `${input.method} ${js(amount)}` });
}

export async function closeTableSession(sessionId: string, opts: { paymentMethod?: string | null } = {}): Promise<void> {
  authorize('operate:floor');
  const s = await get(C.tableSessions, sessionId);
  if (!s || s.status === 'CLOSED') return;
  const orders = await where(C.orders, 'sessionId', sessionId);
  const payments = (await where(C.payments, 'sessionId', sessionId)).sort((a, b) => toDate(a.createdAt)!.getTime() - toDate(b.createdAt)!.getTime());
  const subtotal = orders.reduce((sum, o) => sum + Number(o.total), 0);
  const total = Math.max(0, subtotal - Number(s.discount) + Number(s.tax) + Number(s.serviceCharge) + Number(s.tip));
  const paid = payments.reduce((sum, p) => sum + Number(p.amount), 0);
  const remaining = round((total - paid) * 100) / 100;

  const methods = new Set<string>(payments.map((p) => String(p.method)));
  const finalMethod = opts.paymentMethod ?? 'Cash';
  if (remaining > 0.001) methods.add(finalMethod);
  const list = [...methods];
  const method = list.length > 1 ? 'Mixed' : (list[0] ?? opts.paymentMethod ?? null);

  const t = now();
  const batch = db.batch();
  if (remaining > 0.001) batch.create(ref(C.payments, cuid()), { sessionId, amount: remaining, method: finalMethod, createdAt: t });
  batch.update(ref(C.tableSessions, sessionId), { status: 'CLOSED', closedAt: t, subtotal, total, paymentStatus: 'PAID', paymentMethod: method, updatedAt: t });
  batch.update(ref(C.tables, s.tableId), { state: 'CLEANING', updatedAt: t });
  await batch.commit();
  await logAudit('session.close', 'TableSession', { entityId: sessionId, detail: `${method ?? ''} · total ${js(total)}` });
}

export async function setTableState(tableId: string, state: string): Promise<void> {
  authorize('operate:floor');
  await save(C.tables, tableId, { state });
  await logAudit('table.state', 'Table', { entityId: tableId, detail: state });
}

// ---- Dashboard widget overrides (editable Trending / Top Categories) ----

async function saveDashboardConfig(patch: Record<string, unknown>): Promise<void> {
  await ref(C.dashboardConfig, 'default').set({ ...patch, updatedAt: now() }, { merge: true });
}

export async function setTrendingItem(itemId: string | null): Promise<void> {
  authorize('manage:menu');
  await saveDashboardConfig({ trendingItemId: itemId });
}

export async function setTopCategories(categories: { name: string; percent: number }[] | null): Promise<void> {
  authorize('manage:menu');
  await saveDashboardConfig({ topCategories: categories?.length ? JSON.stringify(categories.slice(0, 3)) : null });
}

// ---- Orders ----

export async function setOrderStatus(id: string, status: string): Promise<void> {
  authorize('manage:orders');
  await save(C.orders, id, { status });
  const order = (await get(C.orders, id))!;
  // On completion, email the customer (online orders capture an email). Mail never blocks the update.
  if (status === 'COMPLETED' && order.customerEmail) {
    try {
      await sendMail(order.customerEmail, Mail.orderCompletedEmail({
        number: order.number,
        customerName: order.customerName,
        items: (order.items ?? []).map((it: Row) => ({ name: it.name, qty: Number(it.qty), price: Number(it.price) })),
        total: Number(order.total),
      }));
    } catch (e) {
      console.error('Order completion email failed (status still updated):', e);
    }
  }
}

// ---- Reservations ----

export async function setReservationStatus(id: string, status: string): Promise<void> {
  authorize('manage:reservations');
  await save(C.reservations, id, { status });
  const r = (await get(C.reservations, id))!;
  if (status === 'COMPLETED' && r.email) {
    try {
      await sendMail(r.email, Mail.reservationCompletedEmail({ reference: r.reference, name: r.name, kind: r.kind }));
    } catch (e) {
      console.error('Reservation completion email failed (status still updated):', e);
    }
  }
}

export async function updateReservation(id: string, input: { date?: string; time?: string | null; guests?: number | null; occasion?: string | null; requests?: string | null }): Promise<void> {
  authorize('manage:reservations');
  const data: Record<string, unknown> = {};
  if (input.date) data.date = ts(jsDate(input.date));
  for (const k of ['time', 'guests', 'occasion', 'requests'] as const) if (k in input) data[k] = input[k];
  await save(C.reservations, id, data);
}

// ---- Staff ----

export async function setEmployeeStatus(id: string, status: string): Promise<void> {
  authorize('manage:staff');
  await save(C.employees, id, { status }, { updatedAt: false });
}

export async function createStaff(input: unknown): Promise<void> {
  authorize('manage:staff');
  const data = V.parse(V.staffSchema, input);
  const outlet = (await db.collection(C.outlets).limit(1).get()).docs[0];
  const id = cuid();
  await ref(C.employees, id).create({
    name: data.name,
    role: data.role,
    email: data.email,
    emailLower: data.email.toLowerCase(),
    phone: orNull(data.phone ?? null),
    avatarUrl: null,
    status: 'OFF',
    active: data.active,
    outletId: outlet?.id ?? 'default',
    userId: null,
    createdAt: now(),
  });
  await setCredentials('employee', id, { email: data.email, passwordHash: data.password ? hashPassword(data.password) : null });
}

export async function updateStaff(id: string, input: unknown): Promise<void> {
  authorize('manage:staff');
  const data = V.parse(V.staffSchema, input);
  await save(C.employees, id, {
    name: data.name,
    role: data.role,
    email: data.email,
    emailLower: data.email.toLowerCase(),
    phone: orNull(data.phone ?? null),
    active: data.active,
  }, { updatedAt: false });
  // Empty password on edit keeps the existing one.
  await setCredentials('employee', id, { email: data.email, ...(data.password ? { passwordHash: hashPassword(data.password) } : {}) });
}

export async function setStaffActive(id: string, active: boolean): Promise<void> {
  authorize('manage:staff');
  await save(C.employees, id, { active }, { updatedAt: false });
}

export async function deleteStaff(id: string): Promise<void> {
  authorize('manage:staff');
  await getOrFail(C.employees, id);
  await nullify(C.tableSessions, 'waiterId', id); // FK SET NULL
  await ref(C.employees, id).delete();
  await ref(C.credentials, `employee_${id}`).delete();
}

// ---- Tables (QR ordering) ----

async function assertTableNumberFree(number: string, exceptId?: string): Promise<void> {
  const clash = await first(C.tables, 'number', number);
  if (clash && clash.id !== exceptId) throw new HttpError(409, `Table number ${number} already exists`);
}

export async function createTable(input: unknown): Promise<Record<string, unknown>> {
  authorize('manage:tables');
  const data = V.parse(V.tableSchema, input);
  await assertTableNumberFree(data.number);
  const id = cuid();
  const t = now();
  const row = { number: data.number, name: orNull(data.name ?? null), code: cuid(), status: data.status, capacity: 4, state: 'AVAILABLE', createdAt: t, updatedAt: t };
  await ref(C.tables, id).create(row);
  const out: Record<string, unknown> = { id, number: row.number, name: row.name, code: row.code, status: row.status, orderCount: 0, createdAt: t.toDate().toISOString() };
  if (out.name === null) delete out.name;
  return out;
}

export async function updateTable(id: string, input: unknown): Promise<void> {
  authorize('manage:tables');
  const data = V.parse(V.tableSchema, input);
  await assertTableNumberFree(data.number, id);
  await save(C.tables, id, { number: data.number, name: orNull(data.name ?? null), status: data.status });
}

export async function setTableStatus(id: string, status: string): Promise<void> {
  authorize('manage:tables');
  await save(C.tables, id, { status });
}

export async function deleteTable(id: string): Promise<void> {
  authorize('manage:tables');
  await getOrFail(C.tables, id);
  // TableSession ON DELETE CASCADE (→ Payment CASCADE, Order.sessionId SET NULL); Order.tableId SET NULL.
  const sessions = await where(C.tableSessions, 'tableId', id);
  for (const s of sessions) {
    for (const p of await where(C.payments, 'sessionId', s.id)) await ref(C.payments, p.id).delete();
    await nullify(C.orders, 'sessionId', s.id);
    await ref(C.tableSessions, s.id).delete();
  }
  await nullify(C.orders, 'tableId', id);
  await ref(C.tables, id).delete();
}

// ---- Gift cards & coupons ----

export async function updateGiftCard(id: string, input: unknown): Promise<void> {
  authorize('manage:coupons');
  const data = V.parse(V.giftCardEditSchema, input);
  await save(C.giftCards, id, {
    customerName: data.customerName,
    customerEmail: orNull(data.customerEmail ?? null) ?? '',
    kind: data.kind,
    amount: data.amount,
    status: data.status,
    paymentStatus: data.paymentStatus,
    expiryDate: data.expiryDate ? ts(jsDate(data.expiryDate)) : null,
  });
}

export async function setGiftCardStatus(id: string, status: string): Promise<void> {
  authorize('manage:coupons');
  await save(C.giftCards, id, { status });
  const g = (await get(C.giftCards, id))!;
  if (status === 'REDEEMED' && g.customerEmail) {
    try {
      await sendMail(g.customerEmail, Mail.giftCardRedeemedEmail({ code: g.code, kind: g.kind, amount: Number(g.amount), name: g.customerName }));
    } catch (e) {
      console.error('Gift card redeemed email failed (status still updated):', e);
    }
  }
}

export async function deleteGiftCard(id: string): Promise<void> {
  authorize('manage:coupons');
  await getOrFail(C.giftCards, id);
  await ref(C.giftCards, id).delete();
}

// ---- Customers ----

async function assertCustomerEmailFree(email: string, exceptId?: string): Promise<void> {
  const clash = await first(C.customers, 'emailLower', email.toLowerCase());
  if (clash && clash.id !== exceptId) throw new HttpError(409, 'A customer with this email already exists');
}

const customerData = (d: z.infer<typeof V.customerSchema>) => ({
  name: d.name,
  email: d.email,
  emailLower: d.email.toLowerCase(),
  phone: orNull(d.phone ?? null),
  address: orNull(d.address ?? null),
  status: d.status,
});

export async function createCustomer(input: unknown): Promise<void> {
  authorize('manage:customers');
  const data = V.parse(V.customerSchema, input);
  await assertCustomerEmailFree(data.email);
  const id = cuid();
  await ref(C.customers, id).create({ ...customerData(data), createdAt: now(), updatedAt: now() });
  await setCredentials('customer', id, { email: data.email, passwordHash: null });
}

export async function updateCustomer(id: string, input: unknown): Promise<void> {
  authorize('manage:customers');
  const data = V.parse(V.customerSchema, input);
  await assertCustomerEmailFree(data.email, id);
  await save(C.customers, id, customerData(data));
  await setCredentials('customer', id, { email: data.email });
}

export async function deleteCustomer(id: string): Promise<void> {
  authorize('manage:customers');
  await getOrFail(C.customers, id);
  for (const coll of [C.orders, C.reservations, C.giftCards, C.tableSessions] as const) await nullify(coll, 'customerId', id); // FK SET NULL
  await ref(C.customers, id).delete();
  await ref(C.credentials, `customer_${id}`).delete();
}

/** Mobile "Delete account" (Play Store): the customer deletes themself. Unlinks and anonymises
 *  past orders / bookings / gift cards / table sessions (kept for accounting), then removes the
 *  customer row and its credentials. Matches by customerId and by the account e-mail. */
export async function deleteOwnCustomerAccount(id: string, email: string): Promise<void> {
  const ANON = 'Deleted customer';
  const scrub: [Coll, string, Record<string, unknown>][] = [
    [C.orders, 'customerEmail', { customerId: null, customerName: ANON, customerEmail: null, customerPhone: null }],
    [C.reservations, 'email', { customerId: null, name: ANON, email: null, phone: null }],
    [C.giftCards, 'customerEmail', { customerId: null, customerName: ANON, customerEmail: null }],
    [C.tableSessions, '', { customerId: null, customerName: ANON }],
  ];
  const emails = [...new Set([email, email.toLowerCase()].filter(Boolean))];
  for (const [coll, emailField, data] of scrub) {
    const rows = new Map<string, Row>();
    for (const r of await where(coll, 'customerId', id)) rows.set(r.id, r);
    if (emailField && emails.length) for (const r of await where(coll, emailField, emails)) rows.set(r.id, r);
    const w = db.bulkWriter();
    for (const r of rows.values()) w.update(ref(coll, r.id), data);
    await w.close();
  }
  await ref(C.customers, id).delete();
  await ref(C.credentials, `customer_${id}`).delete();
}

// ---- Inventory ----

export async function createInventoryItem(input: unknown): Promise<void> {
  authorize('manage:inventory');
  const data = V.parse(V.inventoryItemSchema, input);
  await ref(C.inventoryItems, cuid()).create({ supplier: null, outletId: null, ...data, updatedAt: now() });
}

export async function updateInventoryItem(id: string, input: unknown): Promise<void> {
  authorize('manage:inventory');
  const data = V.parse(V.inventoryItemSchema, input);
  await save(C.inventoryItems, id, data);
}

export async function adjustInventory(id: string, delta: number): Promise<void> {
  authorize('manage:inventory');
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref(C.inventoryItems, id));
    if (!s.exists) return;
    tx.update(s.ref, { quantity: Math.max(0, Number(s.get('quantity')) + delta), updatedAt: now() });
  });
}

export async function deleteInventoryItem(id: string): Promise<void> {
  authorize('manage:inventory');
  await getOrFail(C.inventoryItems, id);
  await ref(C.inventoryItems, id).delete();
}

// ---- Settings ----

export async function updateProfile(input: unknown): Promise<void> {
  authorize('manage:settings');
  const data = V.parse(V.profileSchema, input);
  await ref(C.restaurantProfile, 'default').set({ ...data, updatedAt: now() }, { merge: true });
}

export async function changePassword(input: unknown): Promise<{ ok: boolean; error?: string }> {
  const u = currentUser();
  if (!u || u.kind !== 'user') return { ok: false, error: 'Unauthorized' };
  const data = V.parse(V.passwordSchema, input);
  const user = await get(C.users, u.id);
  if (!user) return { ok: false, error: 'User not found' };
  const cred = await get(C.credentials, `user_${u.id}`);
  if (!cred?.passwordHash || !bcrypt.compareSync(data.currentPassword, String(cred.passwordHash))) {
    return { ok: false, error: 'Current password is incorrect' };
  }
  await setCredentials('user', u.id, { passwordHash: hashPassword(data.newPassword) });
  await ref(C.users, u.id).update({ updatedAt: now() });
  return { ok: true };
}
