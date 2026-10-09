import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description:
    'How Go4Foodie collects, uses, and protects your personal information.',
};

const SECTIONS: { heading: string; body: string[] }[] = [
  {
    heading: 'Introduction',
    body: [
      'Go4Foodie (“we”, “us”, “our”) respects your privacy. This policy explains what information we collect when you visit our website, make a reservation, buy a gift card, or order online, and how we use and protect it.',
    ],
  },
  {
    heading: 'Information We Collect',
    body: [
      'We collect information you provide directly — such as your name, email address, phone number, reservation details, and any messages you send us.',
      'We also collect limited technical information automatically, such as your browser type, device, and pages visited, to help us improve the site.',
    ],
  },
  {
    heading: 'How We Use Your Information',
    body: [
      'We use your information to confirm and manage reservations, fulfill gift-card and online-order requests, respond to inquiries, and — where you have opted in — send occasional updates about events and offerings.',
    ],
  },
  {
    heading: 'Cookies & Tracking',
    body: [
      'Our site uses cookies and similar technologies to remember your preferences and understand how the site is used. You can control cookies through your browser settings; disabling them may affect some features.',
    ],
  },
  {
    heading: 'Sharing Your Information',
    body: [
      'We do not sell your personal information. We share it only with trusted service providers who help us operate the site and our services (for example, reservation, payment, and ordering platforms), and only as needed to provide those services or as required by law.',
    ],
  },
  {
    heading: 'Data Security',
    body: [
      'We use reasonable administrative and technical safeguards to protect your information. No method of transmission or storage is completely secure, however, and we cannot guarantee absolute security.',
    ],
  },
  {
    heading: 'Your Rights',
    body: [
      'You may request access to, correction of, or deletion of your personal information, and you may opt out of marketing communications at any time by contacting us using the details below.',
    ],
  },
  {
    heading: 'Third-Party Links',
    body: [
      'Our site may link to third-party services (such as online ordering or social media). We are not responsible for the privacy practices of those services; please review their policies.',
    ],
  },
  {
    heading: 'Changes to This Policy',
    body: [
      'We may update this policy from time to time. Changes will be posted on this page with an updated revision date.',
    ],
  },
  {
    heading: 'Contact Us',
    body: [
      'Questions about this policy? Email info@go4foodie.com or write to 245 Harbor View Avenue, Boston, MA 02127.',
    ],
  },
];

export default function PrivacyPage() {
  return (
    <>
      <Header />
      <main id="main" className="bg-ink">
        <section className="section pt-36">
          <div className="container max-w-3xl">
            <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold-deep">
              Go4Foodie
            </p>
            <h1 className="mt-4 font-display text-[clamp(2.5rem,6vw,4rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
              Privacy Policy
            </h1>
            <p className="mt-4 text-xs uppercase tracking-[0.2em] text-cream/45">
              Last updated · June 9, 2026
            </p>

            <div className="mt-12 space-y-10">
              {SECTIONS.map((s) => (
                <div key={s.heading}>
                  <h2 className="font-display text-xl font-bold uppercase tracking-tight text-gold">
                    {s.heading}
                  </h2>
                  <div className="mt-3 space-y-3">
                    {s.body.map((p, i) => (
                      <p key={i} className="text-sm leading-relaxed text-cream/70">
                        {p}
                      </p>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
      <Footer showGallery={false} />
    </>
  );
}
