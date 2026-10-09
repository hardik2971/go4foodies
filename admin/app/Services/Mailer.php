<?php

namespace App\Services;

use Illuminate\Mail\Message;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * SMTP mail — port of admin/src/lib/mail.ts on Laravel's mailer (MAIL_* in .env).
 * If SMTP isn't configured, sending is skipped (with a log warning) so flows
 * never break. Templates live in EmailTemplates (same names as email-templates.ts).
 */
final class Mailer
{
    /**
     * @param  array{subject:string, html:string, text?:?string}  $mail  e.g. EmailTemplates::orderCompletedEmail(...)
     * @return array{sent:bool}
     */
    public static function send(string $to, array $mail): array
    {
        $host = config('mail.mailers.smtp.host');
        $user = config('mail.mailers.smtp.username');
        $pass = preg_replace('/\s+/', '', (string) config('mail.mailers.smtp.password')); // app passwords are shown spaced
        if (! $host || ! $user || $pass === '') {
            Log::warning('SMTP not configured — skipping email to '.$to);

            return ['sent' => false];
        }
        if ($pass !== config('mail.mailers.smtp.password')) {
            config(['mail.mailers.smtp.password' => $pass]);
            Mail::purge('smtp'); // rebuild the transport with the cleaned password
        }

        $from = config('mail.from.address') ?: $user;
        Mail::html($mail['html'], function (Message $m) use ($to, $mail, $from) {
            $m->from($from, 'Go4Foodie')->to($to)->subject($mail['subject']);
            if (! empty($mail['text'])) {
                $m->text($mail['text']);
            }
        });

        return ['sent' => true];
    }

    /**
     * mail.ts sendMail({ to, subject, html, text }) signature.
     *
     * @param  array{to:string, subject:string, html:string, text?:?string}  $opts
     * @return array{sent:bool}
     */
    public static function sendMail(array $opts): array
    {
        return self::send($opts['to'], $opts);
    }

    // Convenience pass-throughs so callers can keep the TS names.

    public static function orderConfirmationEmail(array $p): array
    {
        return EmailTemplates::orderConfirmationEmail($p);
    }

    public static function orderCompletedEmail(array $p): array
    {
        return EmailTemplates::orderCompletedEmail($p);
    }

    public static function reservationConfirmationEmail(array $p): array
    {
        return EmailTemplates::reservationConfirmationEmail($p);
    }

    public static function reservationCompletedEmail(array $p): array
    {
        return EmailTemplates::reservationCompletedEmail($p);
    }

    public static function giftCardConfirmationEmail(array $p): array
    {
        return EmailTemplates::giftCardConfirmationEmail($p);
    }

    public static function giftCardRedeemedEmail(array $p): array
    {
        return EmailTemplates::giftCardRedeemedEmail($p);
    }
}
