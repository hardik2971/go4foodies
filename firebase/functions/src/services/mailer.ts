import nodemailer, { type Transporter } from 'nodemailer';
import type { Mail } from './emailTemplates';

/**
 * SMTP mail — port of Services/Mailer.php (MAIL_* env, same names as Laravel's config/mail.php).
 * If SMTP isn't configured, sending is skipped (with a log warning) so flows never break.
 */
let cached: { key: string; transport: Transporter } | null = null;

function transport(host: string, user: string, pass: string): Transporter {
  const port = Number(process.env.MAIL_PORT || 2525);
  const raw = (process.env.MAIL_SCHEME || '').toLowerCase();
  const scheme = raw === 'null' || raw === '(null)' ? '' : raw; // Laravel env() reads "null" as null
  // Symfony mailer: scheme "smtps" (or no scheme on port 465) = implicit TLS, otherwise STARTTLS when offered.
  const secure = scheme === 'smtps' || (!scheme && port === 465);
  const key = [host, port, secure, user, pass].join('|');
  if (cached?.key !== key) {
    cached = { key, transport: nodemailer.createTransport({ host, port, secure, auth: { user, pass } }) };
  }
  return cached.transport;
}

export async function sendMail(to: string, mail: Mail): Promise<{ sent: boolean }> {
  const host = process.env.MAIL_HOST;
  const user = process.env.MAIL_USERNAME;
  const pass = (process.env.MAIL_PASSWORD ?? '').replace(/\s+/g, ''); // app passwords are shown spaced
  if (!host || !user || pass === '') {
    console.warn('SMTP not configured — skipping email to ' + to);
    return { sent: false };
  }
  const from = process.env.MAIL_FROM_ADDRESS || user;
  // Mailer.php always sends as "Go4Foodie" (MAIL_FROM_NAME is not consulted there).
  const info = await transport(host, user, pass).sendMail({
    from: { name: 'Go4Foodie', address: from },
    to,
    subject: mail.subject,
    html: mail.html,
    ...(mail.text ? { text: mail.text } : {}),
  });
  const preview = nodemailer.getTestMessageUrl(info); // only for Ethereal test accounts
  console.log(`Mail sent to ${to}: "${mail.subject}" (${info.messageId})${preview ? ` preview: ${preview}` : ''}`);
  return { sent: true };
}
