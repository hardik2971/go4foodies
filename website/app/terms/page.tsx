import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description:
    'The terms and conditions for using Go4Foodie website and services.',
};

const SECTIONS: { heading: string; body: string[] }[] = [
  {
    heading: 'Acceptance of Terms',
    body: [
      'By accessing or using Go4Foodie website and services, you agree to these Terms of Service. If you do not agree, please do not use the site.',
    ],
  },
  {
    heading: 'Reservations & Cancellations',
    body: [
      'Reservations are subject to availability and confirmation. We ask that you notify us in advance if you need to modify or cancel a booking. Large parties and private events may be subject to additional terms, deposits, or cancellation policies communicated at the time of booking.',
    ],
  },
  {
    heading: 'Gift Cards',
    body: [
      'Gift cards are redeemable for food, beverage, and events at Go4Foodie. They carry no cash value except where required by law, cannot be replaced if lost or stolen, and do not expire.',
    ],
  },
  {
    heading: 'Online Ordering',
    body: [
      'Online orders are fulfilled through a third-party ordering platform. Pricing, availability, and order details are subject to that platform’s terms in addition to these.',
    ],
  },
  {
    heading: 'Intellectual Property',
    body: [
      'All content on this site — including text, logos, imagery, and design — is the property of Go4Foodie or its licensors and may not be reproduced without permission.',
    ],
  },
  {
    heading: 'Acceptable Use',
    body: [
      'You agree not to misuse the site, attempt to disrupt its operation, or use it for any unlawful purpose. We may suspend access for conduct that violates these terms.',
    ],
  },
  {
    heading: 'Limitation of Liability',
    body: [
      'The site and services are provided “as is.” To the fullest extent permitted by law, Go4Foodie is not liable for any indirect or consequential damages arising from your use of the site.',
    ],
  },
  {
    heading: 'Privacy',
    body: [
      'Your use of the site is also governed by our Privacy Policy, which explains how we handle your information.',
    ],
  },
  {
    heading: 'Changes to These Terms',
    body: [
      'We may update these terms from time to time. Continued use of the site after changes are posted constitutes acceptance of the revised terms.',
    ],
  },
  {
    heading: 'Governing Law',
    body: [
      'These terms are governed by the laws of the Commonwealth of Massachusetts, without regard to its conflict-of-laws principles.',
    ],
  },
  {
    heading: 'Contact Us',
    body: [
      'Questions about these terms? Email info@go4foodie.com or write to 245 Harbor View Avenue, Boston, MA 02127.',
    ],
  },
];

export default function TermsPage() {
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
              Terms of Service
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
