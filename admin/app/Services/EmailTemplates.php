<?php

namespace App\Services;

use App\Support\Format;

/**
 * Branded HTML email templates — port of admin/src/lib/email-templates.ts,
 * byte-identical output. Dark "ink" background, gold accent, serif display,
 * matching the storefront theme. Uses table layout + inline styles for broad
 * email-client compatibility. Each returns ['subject', 'html', 'text'].
 * Like the TS template literals, interpolated values are NOT HTML-escaped.
 */
final class EmailTemplates
{
    private const C = [
        'ink' => '#0a1c18',
        'inkSoft' => '#0f2621',
        'border' => '#1f3f36',
        'cream' => '#f7f1e8',
        'muted' => '#93a69f',
        'gold' => '#f5761e',
        'goldDeep' => '#e0541a',
    ];

    /** `$${n.toFixed(2)}` */
    private static function money(float|int $n): string
    {
        return '$'.sprintf('%.2f', $n);
    }

    /** `name.split(' ')[0] || 'there'` */
    private static function firstName(string $name): string
    {
        $first = explode(' ', $name)[0];

        return $first === '' ? 'there' : $first;
    }

    /** JS truthiness for optional string/number params. */
    private static function truthy(mixed $v): bool
    {
        return $v !== null && $v !== '' && $v !== 0 && $v !== 0.0 && $v !== false;
    }

    private static function shell(string $title, string $inner): string
    {
        $C = self::C;

        return <<<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>{$title}</title>
</head>
<body style="margin:0;padding:0;background:{$C['ink']};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['ink']};">
  <tr><td align="center" style="padding:32px 16px;">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:100%;background:{$C['inkSoft']};border:1px solid {$C['border']};border-radius:20px;overflow:hidden;">
      <!-- Header -->
      <tr><td style="padding:32px 36px 24px;text-align:center;border-bottom:1px solid {$C['border']};">
        <div style="font-size:11px;letter-spacing:4px;text-transform:uppercase;color:{$C['gold']};font-family:Georgia,'Times New Roman',serif;">Go4Foodie</div>
        <div style="margin-top:6px;font-size:13px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">Kitchen &amp; Drinks · Boston</div>
      </td></tr>
      {$inner}
      <!-- Footer -->
      <tr><td style="padding:24px 36px 32px;text-align:center;border-top:1px solid {$C['border']};">
        <div style="font-size:12px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.6;">
          245 Harbor View Avenue, Boston, MA 02127<br>
          +1 617 482 6060 · hello@go4foodie.com
        </div>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>
HTML;
    }

    /**
     * @param  array{number:string, customerName:string, items:array<array{name:string,qty:int,price:float}>, total:float, pickupLabel:string, notes?:?string}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function orderConfirmationEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['customerName']);
        $notes = $p['notes'] ?? null;

        $itemsRows = '';
        foreach ($p['items'] as $it) {
            $qty = Format::js($it['qty']);
            $line = self::money($it['qty'] * $it['price']);
            $itemsRows .= <<<HTML

      <tr>
        <td style="padding:10px 0;color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;font-size:14px;">
          <span style="color:{$C['gold']};font-weight:bold;">{$qty}×</span> {$it['name']}
        </td>
        <td align="right" style="padding:10px 0;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;font-size:14px;white-space:nowrap;">{$line}</td>
      </tr>
HTML;
        }

        $total = self::money($p['total']);
        $notesRow = self::truthy($notes)
            ? <<<HTML
<tr><td style="padding:8px 36px 0;">
        <div style="font-size:12px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">Notes: <span style="color:{$C['cream']};">{$notes}</span></div>
      </td></tr>
HTML
            : '';

        $inner = <<<HTML

      <tr><td style="padding:32px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Order confirmed</h1>
        <p style="margin:0;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.6;">
          Thanks, {$firstName} — your take-away order is in. We'll have it ready for pickup.
        </p>
      </td></tr>

      <!-- Order number + pickup -->
      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['ink']};border:1px solid {$C['border']};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">Order number</div>
            <div style="margin-top:4px;font-size:26px;letter-spacing:1px;color:{$C['gold']};font-family:Georgia,'Times New Roman',serif;">{$p['number']}</div>
            <div style="margin-top:10px;font-size:13px;color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;">Pickup: {$p['pickupLabel']}</div>
          </td></tr>
        </table>
      </td></tr>

      <!-- Items -->
      <tr><td style="padding:16px 36px 8px;">
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;padding-bottom:6px;border-bottom:1px solid {$C['border']};">Your order</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          {$itemsRows}
          <tr><td colspan="2" style="border-top:1px solid {$C['border']};padding-top:12px;"></td></tr>
          <tr>
            <td style="color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;">Total</td>
            <td align="right" style="color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-size:20px;">{$total}</td>
          </tr>
        </table>
      </td></tr>
      {$notesRow}
      <tr><td style="padding:24px 36px 8px;"></td></tr>
HTML;

        $text = [
            'Go4Foodie — Order confirmed',
            '',
            "Thanks, {$firstName}! Your take-away order is in.",
            "Order number: {$p['number']}",
            "Pickup: {$p['pickupLabel']}",
            '',
            ...array_map(fn ($it) => '  '.Format::js($it['qty'])."x {$it['name']} — ".self::money($it['qty'] * $it['price']), $p['items']),
            "Total: {$total}",
            self::truthy($notes) ? "Notes: {$notes}" : '',
            '',
            '245 Harbor View Avenue, Boston, MA 02127 · +1 617 482 6060',
        ];
        $text = implode("\n", array_filter($text, fn ($l) => $l !== ''));

        return ['subject' => "Order {$p['number']} confirmed · Go4Foodie", 'html' => self::shell('Order confirmed', $inner), 'text' => $text];
    }

    /**
     * @param  array{number:string, customerName:string, items:array<array{name:string,qty:int,price:float}>, total:float}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function orderCompletedEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['customerName']);

        $itemsRows = '';
        foreach ($p['items'] as $it) {
            $qty = Format::js($it['qty']);
            $line = self::money($it['qty'] * $it['price']);
            $itemsRows .= <<<HTML

      <tr>
        <td style="padding:8px 0;color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;font-size:14px;">
          <span style="color:{$C['gold']};font-weight:bold;">{$qty}×</span> {$it['name']}
        </td>
        <td align="right" style="padding:8px 0;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;font-size:14px;white-space:nowrap;">{$line}</td>
      </tr>
HTML;
        }

        $total = self::money($p['total']);
        $inner = <<<HTML

      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Georgia,serif;">&#9733;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, {$firstName}!</h1>
        <p style="margin:0 auto;max-width:420px;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Your order <span style="color:{$C['gold']};">{$p['number']}</span> is complete. We hope every bite was
          wood-fired, seasonal and worth savoring — thank you for letting us cook for you.
        </p>
      </td></tr>

      <!-- Order recap -->
      <tr><td style="padding:22px 36px 8px;">
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;padding-bottom:6px;border-bottom:1px solid {$C['border']};">What you enjoyed</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          {$itemsRows}
          <tr><td colspan="2" style="border-top:1px solid {$C['border']};padding-top:10px;"></td></tr>
          <tr>
            <td style="color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;">Total</td>
            <td align="right" style="color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-size:18px;">{$total}</td>
          </tr>
        </table>
      </td></tr>

      <!-- Come back CTA -->
      <tr><td style="padding:26px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/order" style="display:inline-block;background:{$C['gold']};color:{$C['ink']};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Order again</a>
        <p style="margin:16px 0 0;font-size:13px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">We can't wait to welcome you back to the table.</p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>
HTML;

        $text = implode("\n", [
            'Go4Foodie',
            '',
            "Thank you, {$firstName}!",
            "Your order {$p['number']} is complete. We hope every bite was worth savoring — thank you for letting us cook for you.",
            '',
            'What you enjoyed:',
            ...array_map(fn ($it) => '  '.Format::js($it['qty'])."x {$it['name']} — ".self::money($it['qty'] * $it['price']), $p['items']),
            "Total: {$total}",
            '',
            'Order again: https://go4foodie.com/order',
            "We can't wait to welcome you back to the table.",
        ]);

        return ['subject' => "Thanks for dining with us, {$firstName}! · Go4Foodie", 'html' => self::shell('Thank you', $inner), 'text' => $text];
    }

    /** "18:30" → "6:30 PM" */
    private static function to12h(?string $t): string
    {
        if ($t === null || $t === '') {
            return '';
        }
        $parts = explode(':', $t);
        $hr = Validation::jsNumber($parts[0]);
        $m = $parts[1] ?? 'undefined';
        if (is_nan($hr)) {
            return "12:{$m} PM";
        }
        $h12 = fmod($hr, 12) ?: 12;

        return Format::js($h12).":{$m} ".($hr < 12 ? 'AM' : 'PM');
    }

    /**
     * @param  array{reference:string, name:string, kind:string, dateLabel:string, time?:?string, guests?:?int, occasion?:?string, requests?:?string, eventType?:?string, guestRange?:?string, space?:?string, message?:?string}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function reservationConfirmationEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['name']);
        $isTable = $p['kind'] === 'TABLE';
        $guests = $p['guests'] ?? null;

        $rows = $isTable
            ? [
                ['Date', $p['dateLabel']],
                ['Time', self::to12h($p['time'] ?? null)],
                ['Guests', self::truthy($guests) ? Format::js($guests) : null],
                ['Occasion', $p['occasion'] ?? null],
                ['Requests', $p['requests'] ?? null],
            ]
            : [
                ['Event', $p['eventType'] ?? null],
                ['Preferred date', $p['dateLabel']],
                ['Estimated guests', $p['guestRange'] ?? null],
                ['Space', $p['space'] ?? null],
                ['Details', $p['message'] ?? null],
            ];
        $rows = array_values(array_filter($rows, fn ($r) => self::truthy($r[1])));

        $detailRows = '';
        foreach ($rows as [$k, $v]) {
            $detailRows .= <<<HTML

      <tr>
        <td style="padding:9px 0;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;font-size:13px;">{$k}</td>
        <td align="right" style="padding:9px 0;color:{$C['cream']};font-family:Arial,Helvetica,sans-serif;font-size:14px;">{$v}</td>
      </tr>
HTML;
        }

        $headline = $isTable ? 'Table reserved' : 'Request received';
        $blurb = $isTable
            ? "Thanks, {$firstName} — your table is booked. We can't wait to host you for some wood-fired, seasonal cooking."
            : "Thanks, {$firstName}. We've received your event request — our events team will reach out within 24 hours to craft your occasion.";
        $refLabel = $isTable ? 'Confirmation' : 'Inquiry reference';

        $inner = <<<HTML

      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">{$headline}</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">{$blurb}</p>
      </td></tr>

      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['ink']};border:1px solid {$C['border']};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">{$refLabel}</div>
            <div style="margin-top:4px;font-size:26px;letter-spacing:1px;color:{$C['gold']};font-family:Georgia,'Times New Roman',serif;">{$p['reference']}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:14px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">{$detailRows}</table>
      </td></tr>
      <tr><td style="padding:22px 36px 8px;"></td></tr>
HTML;

        $text = implode("\n", [
            "Go4Foodie — {$headline}",
            '',
            $blurb,
            "{$refLabel}: {$p['reference']}",
            '',
            ...array_map(fn ($r) => "  {$r[0]}: {$r[1]}", $rows),
            '',
            '245 Harbor View Avenue, Boston, MA 02127 · +1 617 482 6060',
        ]);

        return [
            'subject' => $isTable
                ? "Table reserved {$p['reference']} · Go4Foodie"
                : "Event request {$p['reference']} · Go4Foodie",
            'html' => self::shell($headline, $inner),
            'text' => $text,
        ];
    }

    /**
     * @param  array{reference:string, name:string, kind:string}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function reservationCompletedEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['name']);
        $isTable = $p['kind'] === 'TABLE';

        $blurb = $isTable
            ? 'Thank you for dining with us. We hope your evening at the table was warm, unhurried and delicious — it was a pleasure to host you.'
            : 'Thank you for celebrating with us. We hope your event was everything you imagined — it was an honor to be part of your occasion.';

        $inner = <<<HTML

      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Georgia,serif;">&#9733;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, {$firstName}!</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">{$blurb}</p>
      </td></tr>

      <tr><td style="padding:22px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['ink']};border:1px solid {$C['border']};border-radius:14px;">
          <tr><td style="padding:18px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">Reservation</div>
            <div style="margin-top:4px;font-size:24px;letter-spacing:1px;color:{$C['gold']};font-family:Georgia,'Times New Roman',serif;">{$p['reference']}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:26px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/table-reservation" style="display:inline-block;background:{$C['gold']};color:{$C['ink']};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Book again</a>
        <p style="margin:16px 0 0;font-size:13px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          We'd love to welcome you back to the table soon.<br>If you have a moment, we'd be grateful for your feedback.
        </p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>
HTML;

        $text = implode("\n", [
            'Go4Foodie',
            '',
            "Thank you, {$firstName}!",
            $blurb,
            "Reservation: {$p['reference']}",
            '',
            'Book again: https://go4foodie.com/table-reservation',
            "We'd love to welcome you back to the table soon.",
        ]);

        return [
            'subject' => "Thank you for visiting, {$firstName}! · Go4Foodie",
            'html' => self::shell('Thank you', $inner),
            'text' => $text,
        ];
    }

    /**
     * @param  array{code:string, kind:string, amount:float, name:string, message?:?string, expiryLabel?:?string}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function giftCardConfirmationEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['name']);
        $isGift = $p['kind'] === 'GIFT_CARD';
        $label = $isGift ? 'Gift Card' : 'Coupon';
        $lower = strtolower($label);
        $amount = self::money($p['amount']);
        $message = $p['message'] ?? null;
        $expiryLabel = $p['expiryLabel'] ?? null;

        $expiry = self::truthy($expiryLabel)
            ? "<div style=\"margin-top:6px;font-size:11px;color:{$C['ink']};opacity:.7;font-family:Arial,Helvetica,sans-serif;\">Valid until {$expiryLabel}</div>"
            : "<div style=\"margin-top:6px;font-size:11px;color:{$C['ink']};opacity:.7;font-family:Arial,Helvetica,sans-serif;\">No expiry</div>";
        $messageRow = self::truthy($message)
            ? <<<HTML
<tr><td style="padding:12px 36px 0;text-align:center;">
        <p style="font-size:13px;font-style:italic;color:{$C['muted']};font-family:Georgia,serif;">&ldquo;{$message}&rdquo;</p>
      </td></tr>
HTML
            : '';

        $inner = <<<HTML

      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Georgia,serif;">&#127873;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Your {$lower} is ready</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Thank you, {$firstName}! Your {$amount} {$lower} for Go4Foodie is confirmed and ready to use.
        </p>
      </td></tr>

      <!-- The gold card with the code -->
      <tr><td style="padding:24px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['gold']};border-radius:16px;">
          <tr><td style="padding:24px;text-align:center;">
            <div style="font-size:11px;letter-spacing:3px;text-transform:uppercase;color:{$C['ink']};opacity:.7;font-family:Arial,Helvetica,sans-serif;">Go4Foodie · {$label}</div>
            <div style="margin:10px 0;font-size:30px;font-weight:bold;letter-spacing:3px;color:{$C['ink']};font-family:'Courier New',monospace;">{$p['code']}</div>
            <div style="font-size:22px;font-weight:bold;color:{$C['ink']};font-family:Georgia,'Times New Roman',serif;">{$amount}</div>
            {$expiry}
          </td></tr>
        </table>
      </td></tr>
      {$messageRow}
      <tr><td style="padding:18px 36px 8px;text-align:center;">
        <p style="font-size:13px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Present this code when dining, ordering online, or booking a private event.
        </p>
      </td></tr>
      <tr><td style="padding:14px 36px 8px;"></td></tr>
HTML;

        $text = [
            "Go4Foodie — Your {$label} is ready",
            '',
            "Thank you, {$firstName}! Your {$amount} {$lower} is confirmed.",
            "Code: {$p['code']}",
            "Value: {$amount}",
            self::truthy($expiryLabel) ? "Valid until: {$expiryLabel}" : 'No expiry',
            self::truthy($message) ? "Message: {$message}" : '',
            '',
            'Present this code when dining, ordering online, or booking a private event.',
        ];
        $text = implode("\n", array_filter($text, fn ($l) => $l !== ''));

        return [
            'subject' => "Your {$label} {$p['code']} · Go4Foodie",
            'html' => self::shell("Your {$label}", $inner),
            'text' => $text,
        ];
    }

    /**
     * @param  array{code:string, kind:string, amount:float, name:string}  $p
     * @return array{subject:string, html:string, text:string}
     */
    public static function giftCardRedeemedEmail(array $p): array
    {
        $C = self::C;
        $firstName = self::firstName($p['name']);
        $label = $p['kind'] === 'COUPON' ? 'coupon' : 'gift card';
        $amount = self::money($p['amount']);

        $inner = <<<HTML

      <tr><td style="padding:34px 36px 8px;text-align:center;">
        <div style="display:inline-block;width:56px;height:56px;border-radius:50%;background:{$C['gold']};line-height:56px;font-size:26px;color:{$C['ink']};font-family:Arial,Helvetica,sans-serif;">&#10003;</div>
        <h1 style="margin:18px 0 6px;font-size:28px;color:{$C['cream']};font-family:Georgia,'Times New Roman',serif;font-weight:normal;">Thank you, {$firstName}!</h1>
        <p style="margin:0 auto;max-width:430px;font-size:14px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;line-height:1.7;">
          Your {$label} <span style="color:{$C['gold']};">{$p['code']}</span> ({$amount}) has been redeemed. We hope it made your visit to Go4Foodie all the more memorable.
        </p>
      </td></tr>

      <tr><td style="padding:22px 36px 8px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{$C['ink']};border:1px solid {$C['border']};border-radius:14px;">
          <tr><td style="padding:16px 22px;text-align:center;">
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">Redeemed</div>
            <div style="margin-top:4px;font-size:20px;letter-spacing:1px;color:{$C['gold']};font-family:'Courier New',monospace;">{$p['code']}</div>
            <div style="margin-top:4px;font-size:16px;color:{$C['cream']};font-family:Georgia,serif;">{$amount}</div>
          </td></tr>
        </table>
      </td></tr>

      <tr><td style="padding:24px 36px 6px;text-align:center;">
        <a href="https://go4foodie.com/order" style="display:inline-block;background:{$C['gold']};color:{$C['ink']};text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;padding:12px 28px;border-radius:999px;">Visit again</a>
        <p style="margin:16px 0 0;font-size:13px;color:{$C['muted']};font-family:Arial,Helvetica,sans-serif;">We can't wait to welcome you back to the table.</p>
      </td></tr>
      <tr><td style="padding:18px 36px 8px;"></td></tr>
HTML;

        $text = implode("\n", [
            'Go4Foodie',
            '',
            "Thank you, {$firstName}!",
            "Your {$label} {$p['code']} ({$amount}) has been redeemed. We hope it made your visit all the more memorable.",
            '',
            'Visit again: https://go4foodie.com/order',
            "We can't wait to welcome you back to the table.",
        ]);

        return [
            'subject' => "Your {$label} was redeemed — thank you! · Go4Foodie",
            'html' => self::shell('Redeemed', $inner),
            'text' => $text,
        ];
    }
}
