import type { Metadata } from 'next';
import Link from 'next/link';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import DeletionRequestDialog from '@/components/DeletionRequestDialog';

const SUPPORT_EMAIL = 'info@infidec.com';
const MAILTO = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Delete my Go4Foodie account')}&body=${encodeURIComponent(
  'Hello,\n\nPlease delete my Go4Foodie account and the personal data linked to it.\n\nAccount e-mail: \nName on the account: \n\nThank you.',
)}`;

export const metadata: Metadata = {
  title: 'Delete Your Account',
  description:
    'How to delete your Go4Foodie account (website and Go4Foodie app) and the personal data linked to it.',
  alternates: { canonical: '/delete-account' },
};

/** Contact e-mail, highlighted in the theme colour. */
const Email = () => (
  <a href={MAILTO} className="font-semibold text-gold underline-offset-4 hover:underline">
    {SUPPORT_EMAIL}
  </a>
);

const STEPS = [
  {
    title: 'Send a deletion request',
    text: (
      <>
        Click <span className="text-cream">“Email a deletion request”</span> above and fill in the short form with the
        e-mail address you use to sign in, or email <Email /> with the subject{' '}
        <span className="text-cream">“Delete my Go4Foodie account”</span>. In the Go4Foodie app you can also delete
        your account instantly: <span className="text-cream">Profile → Delete account</span>.
      </>
    ),
  },
  {
    title: 'We confirm your request',
    text: 'We reply to confirm we have received it. If we cannot match the e-mail to an account, we may ask you to confirm the name or phone number on the account.',
  },
  {
    title: 'Your account is deleted',
    text: 'We delete your account and the personal data listed below within 30 days and e-mail you when it is done. After that you can no longer sign in to the Go4Foodie app or website with this account.',
  },
];

const DELETED = [
  'Your account and sign-in details (e-mail address and password)',
  'Your name, phone number and address',
  'Your saved profile and app preferences',
];

const KEPT = [
  'Records of past orders, payments, gift cards and table bookings that we must keep for tax, accounting and legal reasons — kept for up to 7 years, with your name, e-mail and phone number removed or replaced',
  'Payments are processed by Razorpay, Stripe or PayPal. We never store your card details; those providers keep their own records under their privacy policies.',
];

export default function DeleteAccountPage() {
  return (
    <>
      <Header />
      <main id="main" className="bg-ink">
        <section className="section pt-36">
          <div className="container max-w-3xl">
            <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold-deep">Go4Foodie</p>
            <h1 className="mt-4 font-display text-[clamp(2.5rem,6vw,4rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
              Delete Your Account
            </h1>
            <p className="mt-4 text-xs uppercase tracking-[0.2em] text-cream/45">Last updated · October 28, 2026</p>

            <p className="mt-8 text-sm leading-relaxed text-cream/70">
              This page explains how to delete your <span className="text-cream">Go4Foodie</span> account — the account you
              use on the Go4Foodie website and in the <span className="text-cream">Go4Foodie app</span> for Android and iOS
              — and the personal data linked to it. You do not need the app to make a request.
            </p>

            {/* Highlighted contact card */}
            <div className="mt-10 rounded-2xl border border-gold/40 bg-gold/10 p-6 sm:p-8">
              <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold">Request deletion by e-mail</p>
              <a
                href={MAILTO}
                className="mt-3 block break-all font-display text-2xl font-bold text-gold underline-offset-4 hover:underline sm:text-3xl"
              >
                {SUPPORT_EMAIL}
              </a>
              <p className="mt-3 text-sm leading-relaxed text-cream/70">
                Write from the e-mail address on your account and include the name on the account.
              </p>
              <DeletionRequestDialog />
            </div>

            <div className="mt-12 space-y-10">
              <div>
                <h2 className="font-display text-xl font-bold uppercase tracking-tight text-gold">How to delete your account</h2>
                <ol className="mt-5 space-y-5">
                  {STEPS.map((s, i) => (
                    <li key={s.title} className="flex gap-4">
                      <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-gold font-display text-sm font-bold text-ink">
                        {i + 1}
                      </span>
                      <div>
                        <p className="font-semibold text-cream">{s.title}</p>
                        <p className="mt-1 text-sm leading-relaxed text-cream/70">{s.text}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              </div>

              <div>
                <h2 className="font-display text-xl font-bold uppercase tracking-tight text-gold">Data we delete</h2>
                <ul className="mt-3 list-disc space-y-2 pl-5 text-sm leading-relaxed text-cream/70 marker:text-gold">
                  {DELETED.map((d) => (
                    <li key={d}>{d}</li>
                  ))}
                </ul>
              </div>

              <div>
                <h2 className="font-display text-xl font-bold uppercase tracking-tight text-gold">Data we keep</h2>
                <ul className="mt-3 list-disc space-y-2 pl-5 text-sm leading-relaxed text-cream/70 marker:text-gold">
                  {KEPT.map((d) => (
                    <li key={d}>{d}</li>
                  ))}
                </ul>
              </div>

              <div>
                <h2 className="font-display text-xl font-bold uppercase tracking-tight text-gold">Questions</h2>
                <p className="mt-3 text-sm leading-relaxed text-cream/70">
                  Email <Email /> or read our{' '}
                  <Link href="/privacy" className="font-semibold text-gold underline-offset-4 hover:underline">
                    Privacy Policy
                  </Link>
                  .
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer showGallery={false} />
    </>
  );
}
