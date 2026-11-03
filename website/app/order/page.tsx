import { Suspense } from 'react';
import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import OrderPageClient from '@/components/order/OrderPageClient';

export const metadata: Metadata = {
  title: 'Order Online',
  description:
    'Order take away or reserve a dine-in table at Go4Foodie — wood-fired, seasonal cooking, ready when you are.',
};

// Static shell; the live menu and the scanned table (?table=CODE) load in the browser.
export default function OrderPage() {
  return (
    <>
      <Header />
      <main id="main">
        <Suspense fallback={<p className="container py-40 text-center text-sm text-cream/60">Loading menu…</p>}>
          <OrderPageClient />
        </Suspense>
      </main>
      <Footer />
    </>
  );
}
