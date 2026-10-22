import { C, all, db, now, ref, ts, type Row } from '../lib/db';
import { cuid } from '../lib/cuid';
import { local } from '../lib/format';
import { jsDate, orderDefaults, sessionDefaults, uniqueOrderNumber } from './actions';
import { upsertCustomerByEmail } from './customers';
import { orderConfirmationEmail } from './emailTemplates';
import { error, response, type ApiResult } from './json';
import { sendMail } from './mailer';
import * as PaymentGate from './payments/paymentGate';
import * as Scheduling from './scheduling';
import type { OnlineOrderInput } from './zod';

/**
 * Shared online-order placement — port of Services/OnlineOrder.php, used by POST /api/orders
 * (website) and POST /api/mobile/customer/orders (Customer app).
 *  - TAKE_AWAY: pickup order with optional scheduling → persisted as PICKUP.
 *  - DINE_IN:   table QR order → persisted as DINE_IN tied to a table (+ open session).
 * Prices always come from live menu rows. With payAtRestaurant (app customer settling at the
 * counter/table) the gateway gate is skipped and the order is stored unpaid.
 */

/** A cart problem the customer can fix (the PHP RuntimeException path) → 422. */
class CartError extends Error {}

interface Line {
  id: string;
  menuItemId: string;
  name: string;
  qty: number;
  price: number;
}

/** PHP empty() on an optional string ("" and "0" are empty). */
const filled = (s: string | undefined): s is string => s !== undefined && s !== '' && s !== '0';

export async function placeOnlineOrder(data: OnlineOrderInput, payAtRestaurant = false): Promise<ApiResult> {
  const payment = data.payment ?? null;
  const payLater = payAtRestaurant && !payment;

  // Payment gate (enforced once a gateway is configured).
  if (!payLater) {
    const pay = await PaymentGate.accepted(payment);
    if (!pay.ok) return error(pay.reason ?? 'Payment required', 402);
  }
  const paymentProvider = payment?.provider ?? null;
  const razorpayPaymentId = PaymentGate.ref(payment);

  // Cutoff / business-hours validation for scheduled (LATER) pickups.
  if (data.type === 'TAKE_AWAY' && data.scheduleType === 'LATER') {
    const check = Scheduling.validateSlot(data.scheduleDate ?? '', data.scheduleTime ?? '');
    if (!check.ok) return error(check.reason!, 422);
  }

  try {
    // Resolve & price the cart from live menu rows (never trust client prices).
    // Match by id first, then by name (covers content-seeded storefront ids).
    const menuRows = await all(C.menuItems);
    const byId = new Map<string, Row>();
    const byName = new Map<string, Row>();
    for (const m of menuRows) {
      byId.set(m.id, m);
      byName.set(m.name, m); // Map semantics: last row wins
    }

    const lines: Line[] = data.items.map((i) => {
      const mi = byId.get(i.menuItemId) ?? (filled(i.name) ? byName.get(i.name) : undefined);
      if (!mi) throw new CartError('Item not found: ' + (filled(i.name) ? i.name : i.menuItemId));
      if (!mi.available) throw new CartError(`Item unavailable: ${mi.name}`);
      return { id: cuid(), menuItemId: mi.id, name: mi.name, qty: Math.trunc(i.qty), price: Number(mi.price) };
    });
    let total = 0;
    for (const l of lines) total += l.price * l.qty;

    // Single-outlet fallback keeps the required outletId satisfied.
    const outlet = (await db.collection(C.outlets).limit(1).get()).docs[0];
    const outletId = outlet?.id ?? 'online';
    const number = await uniqueOrderNumber();
    const email = data.email || null;
    const phone = data.phone || null;

    // Link/create a customer when we have an email (table orders may omit it).
    const customerId = email ? await upsertCustomerByEmail(email, phone ? { name: data.name, phone } : { name: data.name }) : null;

    const mailItems = lines.map((l) => ({ name: l.name, qty: l.qty, price: l.price }));
    const orderId = cuid();

    // -------- DINE_IN: table QR order --------
    if (data.type === 'DINE_IN') {
      const table = (await db.collection(C.tables).where('code', '==', data.tableCode).get()).docs.find((d) => d.get('status') === 'ACTIVE');
      if (!table) return error('Table not found or inactive', 422);
      const tableNumber = table.get('number');

      await db.runTransaction(async (tx) => {
        // Attach to the table's open session (auto-open one on QR self-seat).
        const open = await tx.get(db.collection(C.tableSessions).where('tableId', '==', table.id).where('status', '==', 'OPEN').limit(1));
        const t = now();
        let sessionId: string;
        if (!open.empty) {
          sessionId = open.docs[0].id;
        } else {
          sessionId = cuid();
          tx.create(ref(C.tableSessions, sessionId), { ...sessionDefaults(), tableId: table.id, status: 'OPEN', openedAt: t, customerName: data.name, createdAt: t, updatedAt: t });
          tx.update(ref(C.tables, table.id), { state: 'OCCUPIED', updatedAt: t });
        }
        tx.create(ref(C.orders, orderId), {
          ...orderDefaults(),
          number,
          type: 'DINE_IN',
          status: 'PENDING',
          channel: 'ONLINE',
          paymentMethod: payment ? 'ONLINE' : null,
          paymentProvider,
          razorpayPaymentId,
          total,
          outletId,
          customerName: data.name,
          customerEmail: email,
          customerPhone: phone,
          customerId,
          tableId: table.id,
          tableNumber,
          sessionId,
          notes: data.notes ?? null,
          items: lines,
          createdAt: t,
          updatedAt: t,
        });
      });

      // Optional receipt email if the guest provided one.
      if (email) {
        await mail(email, { number, customerName: data.name, items: mailItems, total, pickupLabel: `Dine-in · Table ${tableNumber}`, notes: data.notes ?? null });
      }

      return response({ number, id: orderId, total, tableNumber }, 201);
    }

    // -------- TAKE_AWAY: pickup order --------
    const later = data.scheduleType === 'LATER';
    const pickup = Scheduling.estimatePickup(data.scheduleType, data.scheduleDate ?? null, data.scheduleTime ?? null);
    const t = now();
    await ref(C.orders, orderId).create({
      ...orderDefaults(),
      number,
      type: 'PICKUP', // "Take Away"
      status: 'PENDING',
      channel: 'ONLINE',
      paymentMethod: payLater ? null : 'ONLINE',
      paymentProvider,
      razorpayPaymentId,
      total,
      outletId,
      customerName: data.name,
      customerEmail: email,
      customerPhone: data.phone,
      customerId,
      scheduleType: data.scheduleType,
      scheduleDate: later ? ts(jsDate(String(data.scheduleDate))) : null,
      scheduleTime: later ? data.scheduleTime : null,
      notes: data.notes ?? null,
      items: lines,
      createdAt: t,
      updatedAt: t,
    });

    const lp = local(pickup).setLocale('en-US');
    const pickupLabel = later ? lp.toFormat('ccc, LLL d, h:mm a') : `As soon as possible (around ${lp.toFormat('h:mm a')})`;
    if (email) {
      await mail(email, { number, customerName: data.name, items: mailItems, total, pickupLabel, notes: data.notes ?? null });
    }

    return response({ number, id: orderId, total, estimatedPickup: pickup.toISOString() }, 201);
  } catch (e) {
    console.error(e);
    return e instanceof CartError ? error(e.message, 422) : error('Could not place order', 503);
  }
}

/** Confirmation email — never fail the order if mail/SMTP errors. */
async function mail(to: string, input: Parameters<typeof orderConfirmationEmail>[0]): Promise<void> {
  try {
    await sendMail(to, orderConfirmationEmail(input));
  } catch (e) {
    console.error(e);
  }
}
