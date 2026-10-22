/**
 * Branded HTML email templates — port of Services/EmailTemplates.php (itself a byte-identical
 * port of admin/src/lib/email-templates.ts). Dark "ink" background, gold accent, serif display,
 * matching the storefront theme. Uses table layout + inline styles for broad email-client
 * compatibility. Each returns {subject, html, text}.
 * Like the TS template literals, interpolated values are NOT HTML-escaped.
 */

export interface Mail {
  subject: string;
  html: string;
  text?: string | null;
}

const C = {
  ink: '#0a1c18',
  inkSoft: '#0f2621',
  border: '#1f3f36',
  cream: '#f7f1e8',
  muted: '#93a69f',
  gold: '#f5761e',
  goldDeep: '#e0541a',
};

const money = (n: number): string => `$${n.toFixed(2)}`;

const firstName = (name: string): string => name.split(' ')[0] || 'there';

/** JS truthiness for optional string/number params. */
const truthy = (v: unknown): boolean => v !== null && v !== undefined && v !== '' && v !== 0 && v !== false && !Number.isNaN(v);

interface Line {
  name: string;
  qty: number;
  price: number;
}

function shell(title: string, inner: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>${title}</title>
</head>
<body style="margin:0;padding:0;background:${C.ink};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.ink};">
  <tr><td align="center" style="padding:32px 16px;">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:100%;background:${C.inkSoft};border:1px solid ${C.border};border-radius:20px;overflow:hidden;">
      <!-- Header -->
      <tr><td style="padding:32px 36px 24px;text-align:center;border-bottom:1px solid ${C.border};">
        <div style="font-size:11px;letter-spacing:4px;text-transform:uppercase;color:${C.gold};font-family:Georgia,'Times New Roman',serif;">Go4Foodie</div>
        <div style="margin-top:6px;font-size:13px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">Kitchen &amp; Drinks · Boston</div>
      </td></tr>
      ${inner}
      <!-- Footer -->
      <tr><td style="padding:24px 36px 32px;text-align:center;border-top:1px solid ${C.border};">
        <div style="font-size:12px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.6;">
          245 Harbor View Avenue, Boston, MA 02127<br>
          +1 617 482 6060 · hello@go4foodie.com
        </div>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

export function orderConfirmationEmail(p: { number: string; customerName: string; items: Line[]; total: number; pickupLabel: string; notes?: string | null }): Required<Mail> {
  const first = firstName(p.customerName);
  const notes = p.notes ?? null;

  const itemsRows = p.items
    .map(
      (it) => `
      <tr>
        <td style="padding:10px 0;color:${C.cream};font-family:Arial,Helvetica,sans-serif;font-size:14px;">
          <span style="color:${C.gold};font-weight:bold;">${it.qty}×</span> ${it.name}
        </td>
        <td align="right" style="padding:10px 0;color:${C.muted};font-family:Arial,Helvetica,sans-serif;font-size:14px;white-space:nowrap;">${money(it.qty * it.price)}</td>
      </tr>`,
    )
    .join('');

  const total = money(p.total);
  const notesRow = truthy(notes)
    ? `<tr><td style="padding:8px 36px 0;">
        <div style="font-size:12px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">Notes: <span style="color:${C.cream};">${notes}</span></div>
      </td></tr>`
    : '';

  const inner = `
      <tr><td style="padding:32px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Order confirmed</h1>
        <p style="margin:0;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.6;">
          Thanks, ${first} — your take-away order is in. We'll have it ready for pickup.
        </p>
      </td></tr>

      <!-- Order number + pickup -->
      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.ink};border:1px solid ${C.border};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">Order number</div>
            <div style="margin-top:4px;font-size:26px;letter-spacing:1px;color:${C.gold};font-family:Georgia,'Times New Roman',serif;">${p.number}</div>
            <div style="margin-top:10px;font-size:13px;color:${C.cream};font-family:Arial,Helvetica,sans-serif;">Pickup: ${p.pickupLabel}</div>
          </td></tr>
        </table>
      </td></tr>

      <!-- Items -->
      <tr><td style="padding:16px 36px 8px;">
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;padding-bottom:6px;border-bottom:1px solid ${C.border};">Your order</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${itemsRows}
          <tr><td colspan="2" style="border-top:1px solid ${C.border};padding-top:12px;"></td></tr>
          <tr>
            <td style="color:${C.cream};font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;">Total</td>
            <td align="right" style="color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-size:20px;">${total}</td>
          </tr>
        </table>
      </td></tr>
      ${notesRow}
      <tr><td style="padding:24px 36px 8px;"></td></tr>`;

  const text = [
    'Go4Foodie — Order confirmed',
    '',
    `Thanks, ${first}! Your take-away order is in.`,
    `Order number: ${p.number}`,
    `Pickup: ${p.pickupLabel}`,
    '',
    ...p.items.map((it) => `  ${it.qty}x ${it.name} — ${money(it.qty * it.price)}`),
    `Total: ${total}`,
    truthy(notes) ? `Notes: ${notes}` : '',
    '',
    '245 Harbor View Avenue, Boston, MA 02127 · +1 617 482 6060',
  ]
    .filter((l) => l !== '')
    .join('\n');

  return { subject: `Order ${p.number} confirmed · Go4Foodie`, html: shell('Order confirmed', inner), text };
}

export function orderCompletedEmail(p: { number: string; customerName: string; items: Line[]; total: number }): Required<Mail> {
  const first = firstName(p.customerName);

  const itemsRows = p.items
    .map(
      (it) => `
      <tr>
        <td style="padding:8px 0;color:${C.cream};font-family:Arial,Helvetica,sans-serif;font-size:14px;">
          <span style="color:${C.gold};font-weight:bold;">${it.qty}×</span> ${it.name}
        </td>
        <td align="right" style="padding:8px 0;color:${C.muted};font-family:Arial,Helvetica,sans-serif;font-size:14px;white-space:nowrap;">${money(it.qty * it.price)}</td>
      </tr>`,
    )
    .join('');

  const total = money(p.total);
  const inner = `
      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Georgia,serif;">&#9733;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, ${first}!</h1>
        <p style="margin:0 auto;max-width:420px;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Your order <span style="color:${C.gold};">${p.number}</span> is complete. We hope every bite was
          wood-fired, seasonal and worth savoring — thank you for letting us cook for you.
        </p>
      </td></tr>

      <!-- Order recap -->
      <tr><td style="padding:22px 36px 8px;">
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;padding-bottom:6px;border-bottom:1px solid ${C.border};">What you enjoyed</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${itemsRows}
          <tr><td colspan="2" style="border-top:1px solid ${C.border};padding-top:10px;"></td></tr>
          <tr>
            <td style="color:${C.cream};font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;">Total</td>
            <td align="right" style="color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-size:18px;">${total}</td>
          </tr>
        </table>
      </td></tr>

      <!-- Come back CTA -->
      <tr><td style="padding:26px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/order" style="display:inline-block;background:${C.gold};color:${C.ink};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Order again</a>
        <p style="margin:16px 0 0;font-size:13px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">We can't wait to welcome you back to the table.</p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>`;

  const text = [
    'Go4Foodie',
    '',
    `Thank you, ${first}!`,
    `Your order ${p.number} is complete. We hope every bite was worth savoring — thank you for letting us cook for you.`,
    '',
    'What you enjoyed:',
    ...p.items.map((it) => `  ${it.qty}x ${it.name} — ${money(it.qty * it.price)}`),
    `Total: ${total}`,
    '',
    'Order again: https://go4foodie.com/order',
    "We can't wait to welcome you back to the table.",
  ].join('\n');

  return { subject: `Thanks for dining with us, ${first}! · Go4Foodie`, html: shell('Thank you', inner), text };
}

/** "18:30" → "6:30 PM" */
function to12h(t?: string | null): string {
  if (!t) return '';
  const [h, m] = t.split(':');
  const hr = Number(h);
  const h12 = hr % 12 || 12;
  return `${h12}:${m} ${hr < 12 ? 'AM' : 'PM'}`;
}

export function reservationConfirmationEmail(p: {
  reference: string;
  name: string;
  kind: string;
  dateLabel: string;
  time?: string | null;
  guests?: number | null;
  occasion?: string | null;
  requests?: string | null;
  eventType?: string | null;
  guestRange?: string | null;
  space?: string | null;
  message?: string | null;
}): Required<Mail> {
  const first = firstName(p.name);
  const isTable = p.kind === 'TABLE';

  const rows = (
    isTable
      ? [
          ['Date', p.dateLabel],
          ['Time', to12h(p.time)],
          ['Guests', truthy(p.guests) ? String(p.guests) : null],
          ['Occasion', p.occasion],
          ['Requests', p.requests],
        ]
      : [
          ['Event', p.eventType],
          ['Preferred date', p.dateLabel],
          ['Estimated guests', p.guestRange],
          ['Space', p.space],
          ['Details', p.message],
        ]
  ).filter((r): r is [string, string] => truthy(r[1]));

  const detailRows = rows
    .map(
      ([k, v]) => `
      <tr>
        <td style="padding:9px 0;color:${C.muted};font-family:Arial,Helvetica,sans-serif;font-size:13px;">${k}</td>
        <td align="right" style="padding:9px 0;color:${C.cream};font-family:Arial,Helvetica,sans-serif;font-size:14px;">${v}</td>
      </tr>`,
    )
    .join('');

  const headline = isTable ? 'Table reserved' : 'Request received';
  const blurb = isTable
    ? `Thanks, ${first} — your table is booked. We can't wait to host you for some wood-fired, seasonal cooking.`
    : `Thanks, ${first}. We've received your event request — our events team will reach out within 24 hours to craft your occasion.`;
  const refLabel = isTable ? 'Confirmation' : 'Inquiry reference';

  const inner = `
      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">${headline}</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">${blurb}</p>
      </td></tr>

      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.ink};border:1px solid ${C.border};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">${refLabel}</div>
            <div style="margin-top:4px;font-size:26px;letter-spacing:1px;color:${C.gold};font-family:Georgia,'Times New Roman',serif;">${p.reference}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:14px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">${detailRows}</table>
      </td></tr>
      <tr><td style="padding:22px 36px 8px;"></td></tr>`;

  const text = [
    `Go4Foodie — ${headline}`,
    '',
    blurb,
    `${refLabel}: ${p.reference}`,
    '',
    ...rows.map((r) => `  ${r[0]}: ${r[1]}`),
    '',
    '245 Harbor View Avenue, Boston, MA 02127 · +1 617 482 6060',
  ].join('\n');

  return {
    subject: isTable ? `Table reserved ${p.reference} · Go4Foodie` : `Event request ${p.reference} · Go4Foodie`,
    html: shell(headline, inner),
    text,
  };
}

export function reservationCompletedEmail(p: { reference: string; name: string; kind: string }): Required<Mail> {
  const first = firstName(p.name);
  const isTable = p.kind === 'TABLE';

  const blurb = isTable
    ? 'Thank you for dining with us. We hope your evening at the table was warm, unhurried and delicious — it was a pleasure to host you.'
    : 'Thank you for celebrating with us. We hope your event was everything you imagined — it was an honor to be part of your occasion.';

  const inner = `
      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Georgia,serif;">&#9733;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, ${first}!</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">${blurb}</p>
      </td></tr>

      <tr><td style="padding:22px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.ink};border:1px solid ${C.border};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">Reservation</div>
            <div style="margin-top:4px;font-size:24px;letter-spacing:1px;color:${C.gold};font-family:Georgia,'Times New Roman',serif;">${p.reference}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:26px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/table-reservation" style="display:inline-block;background:${C.gold};color:${C.ink};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Book again</a>
        <p style="margin:16px 0 0;font-size:13px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          We'd love to welcome you back to the table soon.<br>If you have a moment, we'd be grateful for your feedback.
        </p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>`;

  const text = [
    'Go4Foodie',
    '',
    `Thank you, ${first}!`,
    blurb,
    `Reservation: ${p.reference}`,
    '',
    'Book again: https://go4foodie.com/table-reservation',
    "We'd love to welcome you back to the table soon.",
  ].join('\n');

  return { subject: `Thank you for visiting, ${first}! · Go4Foodie`, html: shell('Thank you', inner), text };
}

export function giftCardConfirmationEmail(p: { code: string; kind: string; amount: number; name: string; message?: string | null; expiryLabel?: string | null }): Required<Mail> {
  const first = firstName(p.name);
  const isGift = p.kind === 'GIFT_CARD';
  const label = isGift ? 'Gift Card' : 'Coupon';
  const lower = label.toLowerCase();
  const amount = money(p.amount);
  const message = p.message ?? null;
  const expiryLabel = p.expiryLabel ?? null;

  const expiry = truthy(expiryLabel)
    ? `<div style="margin-top:6px;font-size:11px;color:${C.ink};opacity:.7;font-family:Arial,Helvetica,sans-serif;">Valid until ${expiryLabel}</div>`
    : `<div style="margin-top:6px;font-size:11px;color:${C.ink};opacity:.7;font-family:Arial,Helvetica,sans-serif;">No expiry</div>`;
  const messageRow = truthy(message)
    ? `<tr><td style="padding:12px 36px 0;text-align:center;">
        <p style="font-size:13px;font-style:italic;color:${C.muted};font-family:Georgia,serif;">&ldquo;${message}&rdquo;</p>
      </td></tr>`
    : '';

  const inner = `
      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Georgia,serif;">&#127873;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Your ${lower} is ready</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Thank you, ${first}! Your ${amount} ${lower} for Go4Foodie is confirmed and ready to use.
        </p>
      </td></tr>

      <!-- The gold card with the code -->
      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.gold};border-radius:16px;">
          <tr><td style="padding:24px;text-align:center;">
            <div style="font-size:11px;letter-spacing:3px;text-transform:uppercase;color:${C.ink};opacity:.7;font-family:Arial,Helvetica,sans-serif;">Go4Foodie · ${label}</div>
            <div style="margin:10px 0;font-size:30px;font-weight:bold;letter-spacing:3px;color:${C.ink};font-family:'Courier New',monospace;">${p.code}</div>
            <div style="font-size:22px;font-weight:bold;color:${C.ink};font-family:Georgia,'Times New Roman',serif;">${amount}</div>
            ${expiry}
          </td></tr>
        </table>
      </td></tr>
      ${messageRow}
      <tr><td style="padding:18px 36px 8px;text-align:center;">
        <p style="font-size:13px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Present this code when dining, ordering online, or booking a private event.
        </p>
      </td></tr>
      <tr><td style="padding:14px 36px 8px;"></td></tr>`;

  const text = [
    `Go4Foodie — Your ${label} is ready`,
    '',
    `Thank you, ${first}! Your ${amount} ${lower} is confirmed.`,
    `Code: ${p.code}`,
    `Value: ${amount}`,
    truthy(expiryLabel) ? `Valid until: ${expiryLabel}` : 'No expiry',
    truthy(message) ? `Message: ${message}` : '',
    '',
    'Present this code when dining, ordering online, or booking a private event.',
  ]
    .filter((l) => l !== '')
    .join('\n');

  return { subject: `Your ${label} ${p.code} · Go4Foodie`, html: shell(`Your ${label}`, inner), text };
}

export function giftCardRedeemedEmail(p: { code: string; kind: string; amount: number; name: string }): Required<Mail> {
  const first = firstName(p.name);
  const label = p.kind === 'COUPON' ? 'coupon' : 'gift card';
  const amount = money(p.amount);

  const inner = `
      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:${C.gold};line-height:56px;font-size:26px;color:${C.ink};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:${C.cream};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, ${first}!</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Your ${label} <span style="color:${C.gold};">${p.code}</span> (${amount}) has been redeemed. We hope it made your visit to Go4Foodie all the more memorable.
        </p>
      </td></tr>

      <tr><td style="padding:22px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.ink};border:1px solid ${C.border};border-radius:14px;">
          <tr><td style="padding:16px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">Redeemed</div>
            <div style="margin-top:4px;font-size:20px;letter-spacing:1px;color:${C.gold};font-family:'Courier New',monospace;">${p.code}</div>
            <div style="margin-top:4px;font-size:16px;color:${C.cream};font-family:Georgia,serif;">${amount}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:24px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/order" style="display:inline-block;background:${C.gold};color:${C.ink};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Visit again</a>
        <p style="margin:16px 0 0;font-size:13px;color:${C.muted};font-family:Arial,Helvetica,sans-serif;">We can't wait to welcome you back to the table.</p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>`;

  const text = [
    'Go4Foodie',
    '',
    `Thank you, ${first}!`,
    `Your ${label} ${p.code} (${amount}) has been redeemed. We hope it made your visit all the more memorable.`,
    '',
    'Visit again: https://go4foodie.com/order',
    "We can't wait to welcome you back to the table.",
  ].join('\n');

  return { subject: `Your ${label} was redeemed — thank you! · Go4Foodie`, html: shell('Redeemed', inner), text };
}
