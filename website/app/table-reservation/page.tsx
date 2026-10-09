import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import ReservationFlow from '@/components/ReservationFlow';

export const metadata: Metadata = {
  title: 'Table Reservation',
  description:
    'Reserve your table at Go4Foodie in a few steps — choose your date, party size and time for an unforgettable evening.',
};

export default function TableReservationPage() {
  return (
    <>
      <Header />
      <main id="main">
        <ReservationFlow />
      </main>
      <Footer />
    </>
  );
}
