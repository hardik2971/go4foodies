import Header from '@/components/Header';
import Hero from '@/components/Hero';
import Marquee from '@/components/Marquee';
import Menu from '@/components/Menu';
import Kitchen from '@/components/Kitchen';
import Stories from '@/components/Stories';
import Testimonials from '@/components/Testimonials';
import Visit from '@/components/Visit';
import GiftCard from '@/components/GiftCard';
import Footer from '@/components/Footer';

export default function Home() {
  return (
    <>
      <Header />
      <main id="main">
        <Hero />
        <Marquee />
        <Menu />
        <Kitchen />
        <Stories />
        {/* <Contact /> */}
        <Testimonials />
        <Visit />
        <GiftCard />
      </main>
      <Footer />
    </>
  );
}
