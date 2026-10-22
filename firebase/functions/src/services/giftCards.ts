import { randomInt } from 'node:crypto';
import { C, db, now, ref, ts } from '../lib/db';
import { cuid } from '../lib/cuid';
import { local } from '../lib/format';
import { upsertCustomerByEmail } from './customers';
import { giftCardConfirmationEmail } from './emailTemplates';
import { error, response, type ApiResult } from './json';
import { sendMail } from './mailer';
import * as PaymentGate from './payments/paymentGate';
import { phpRound } from './payments/util';
import { giftCardPurchaseSchema, safeParse } from './zod';

/** Gift card / coupon purchase of Api/GiftCardController.php — shared with the Customer app. */

function genCode(kind: string): string {
  const prefix = kind === 'COUPON' ? 'COUPON' : 'GIFT';
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTUVWXYZ';
  let body = '';
  for (let i = 0; i < 6; i++) body += alphabet[randomInt(0, 33)];
  return `${prefix}-${body}`;
}

/** POST /api/gift-cards — shared with the Customer app (/api/mobile/customer/gift-cards). */
export async function purchase(input: unknown): Promise<ApiResult> {
  const [data, issues] = safeParse(giftCardPurchaseSchema, input);
  if (!data) return error('Invalid purchase', 400, { issues });
  const email = data.email || '';
  const payment = data.payment ?? null;

  // Payment gate (enforced once a gateway is configured).
  const pay = await PaymentGate.accepted(payment);
  if (!pay.ok) return error(pay.reason ?? 'Payment required', 402);

  try {
    // Coupons expire in a year; gift cards never expire.
    const expiryDate = data.kind === 'COUPON' ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) : null;

    // Link/create a customer when we have an email.
    const customerId = email ? await upsertCustomerByEmail(email, { name: data.name }) : null;

    // Generate a unique code (retry on the rare collision).
    let created: { id: string; code: string } | null = null;
    for (let attempt = 0; attempt < 5 && !created; attempt++) {
      const code = genCode(data.kind);
      const id = cuid();
      created = await db.runTransaction(async (tx) => {
        const clash = await tx.get(db.collection(C.giftCards).where('code', '==', code).limit(1));
        if (!clash.empty) return null; // unique-constraint collision on code → retry
        const t = now();
        tx.create(ref(C.giftCards, id), {
          code,
          kind: data.kind,
          customerName: data.name,
          customerEmail: email,
          customerId,
          amount: phpRound(data.amount * 100) / 100, // decimal(10,2)
          message: data.message ?? null,
          expiryDate: expiryDate ? ts(expiryDate) : null,
          paymentStatus: 'PAID',
          paymentProvider: payment?.provider ?? null,
          razorpayPaymentId: PaymentGate.ref(payment),
          status: 'ACTIVE',
          createdAt: t,
          updatedAt: t,
        });
        return { id, code };
      });
    }
    if (!created) return error('Could not generate a code, please retry', 503);

    if (email) {
      try {
        const mail = giftCardConfirmationEmail({
          code: created.code,
          kind: data.kind,
          amount: data.amount,
          name: data.name,
          message: data.message ?? null,
          expiryLabel: expiryDate ? local(expiryDate).setLocale('en-US').toFormat('LLL d, yyyy') : null,
        });
        await sendMail(email, mail);
      } catch (e) {
        console.error(e);
      }
    }

    return response({ code: created.code, id: created.id, amount: data.amount, kind: data.kind }, 201);
  } catch (e) {
    console.error(e);
    return error('Could not complete purchase', 503);
  }
}
