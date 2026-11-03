import { C, db, first, now } from '../lib/db';
import { cuid } from '../lib/cuid';
import { sendMail } from './mailer';
import { error, noStore, type ApiResult } from './json';
import { safeParse, z } from './zod';

/**
 * POST /api/account-deletion — the website's /delete-account form (Google Play "web deletion
 * request"). Stores the request in `deletionRequests`, e-mails the support inbox and sends the
 * user a confirmation. The account itself is deleted by staff (Admin → Customers) after checking
 * the request; customers can also delete instantly in the app (DELETE /api/mobile/auth/me).
 */

const schema = z.object({
  name: z.string().trim().min(2, 'Enter the name on your account').max(120),
  email: z.string().trim().toLowerCase().email('Enter a valid e-mail address').max(200),
  phone: z.string().trim().max(40).optional().or(z.literal('')),
  reason: z.string().trim().max(1000).optional().or(z.literal('')),
  confirm: z.literal(true, { errorMap: () => ({ message: 'Please confirm you want your account deleted' }) }),
  website: z.string().max(0).optional().or(z.literal('')), // honeypot: bots fill every field
});

const SUPPORT = () => process.env.DELETION_NOTIFY_EMAIL || 'info@infidec.com';

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

function page(title: string, rows: [string, string][], intro: string): string {
  const body = rows
    .map(([k, v]) => `<tr><td style="padding:6px 12px 6px 0;color:#93a69f;white-space:nowrap;vertical-align:top">${esc(k)}</td><td style="padding:6px 0;color:#f7f1e8">${esc(v)}</td></tr>`)
    .join('');
  return `<!doctype html><html><body style="margin:0;padding:32px 16px;background:#0a1c18;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:560px;margin:0 auto;background:#0f2621;border:1px solid #1f3f36;border-radius:16px;padding:28px 32px">
<div style="font-size:11px;letter-spacing:4px;text-transform:uppercase;color:#f5761e;font-family:Georgia,serif">Go4Foodie</div>
<h1 style="margin:12px 0 8px;font-size:22px;color:#f7f1e8;font-family:Georgia,serif;font-weight:normal">${esc(title)}</h1>
<p style="margin:0 0 16px;font-size:14px;line-height:1.6;color:#93a69f">${intro}</p>
<table role="presentation" style="font-size:14px;border-collapse:collapse">${body}</table>
</div></body></html>`;
}

export async function create(input: unknown): Promise<ApiResult> {
  const [d, issues] = safeParse(schema, input);
  if (!d) return error(issues[0]?.message ?? 'Invalid request', 400, { issues });
  if (d.website) return noStore({ ok: true }); // silently drop bots

  const customer = await first(C.customers, 'emailLower', d.email);
  const id = cuid();
  const reference = `DEL-${id.slice(-6).toUpperCase()}`;
  const t = now();
  await db.collection('deletionRequests').doc(id).create({
    reference,
    name: d.name,
    email: d.email,
    phone: d.phone || null,
    reason: d.reason || null,
    customerId: customer?.id ?? null,
    status: 'PENDING',
    createdAt: t,
    updatedAt: t,
  });

  const rows: [string, string][] = [
    ['Reference', reference],
    ['Name', d.name],
    ['E-mail', d.email],
    ['Phone', d.phone || '—'],
    ['Reason', d.reason || '—'],
    ['Account found', customer ? `Yes (customer ${customer.id})` : 'No matching account'],
  ];
  const text = rows.map(([k, v]) => `${k}: ${v}`).join('\n');
  // Mail problems must not lose the request — it is already stored.
  await Promise.allSettled([
    sendMail(SUPPORT(), {
      subject: `Account deletion request ${reference} · ${d.email}`,
      html: page('Account deletion request', rows, 'A user asked to delete their Go4Foodie account from the website. Verify the request, then delete the customer in Admin → Customers within 30 days.'),
      text,
    }),
    sendMail(d.email, {
      subject: `We received your account deletion request (${reference}) · Go4Foodie`,
      html: page('We received your request', [['Reference', reference], ['Name', d.name], ['E-mail', d.email]],
        `Hi ${esc(d.name.split(' ')[0])}, we have received your request to delete your Go4Foodie account. We will delete your account and personal data within 30 days and e-mail you when it is done. If you did not make this request, reply to this e-mail or write to ${esc(SUPPORT())}.`),
      text: `We received your request to delete your Go4Foodie account.\nReference: ${reference}\nWe will delete your account within 30 days. Didn't ask for this? Write to ${SUPPORT()}.`,
    }),
  ]).then((r) => r.forEach((x) => x.status === 'rejected' && console.error('Deletion request mail failed', x.reason)));

  return noStore({ ok: true, reference }, 201);
}
