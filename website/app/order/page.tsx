import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import OrderFlow from '@/components/order/OrderFlow';
import TableOrderFlow, { type TableInfo } from '@/components/order/TableOrderFlow';
import { ADMIN_API_URL } from '@/lib/admin-api';
import { MENU_ITEMS } from '@/lib/content';
import type { OrderMenuItem } from '@/lib/order';

export const metadata: Metadata = {
  title: 'Order Online',
  description:
    'Order take away or reserve a dine-in table at Go4Foodie — wood-fired, seasonal cooking, ready when you are.',
};

// Always fetch the freshest menu at request time.
export const dynamic = 'force-dynamic';

// Fallback to the static site menu if the admin API is unreachable, so the page
// always renders. Online ordering still requires the admin/DB to be live.
function fallbackMenu(): { items: OrderMenuItem[]; categories: string[] } {
  const items: OrderMenuItem[] = MENU_ITEMS.map((m) => ({
    id: m.id,
    name: m.name,
    description: m.desc,
    price: m.price,
    rating: m.rating,
    tag: m.tag,
    category: m.category,
    imageUrl: m.image,
  }));
  const categories = Array.from(new Set(items.map((i) => i.category)));
  return { items, categories };
}

async function getMenu(): Promise<{ items: OrderMenuItem[]; categories: string[] }> {
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/menu`, { cache: 'no-store' });
    if (!res.ok) return fallbackMenu();
    const data = (await res.json()) as { items: OrderMenuItem[]; categories: string[] };
    if (!data.items?.length) return fallbackMenu();
    return data;
  } catch {
    return fallbackMenu();
  }
}

// Resolve a scanned table QR code to its table (TASK 5). Returns null if the
// code is missing/invalid so the page falls back to the normal order flow.
async function getTable(code?: string): Promise<TableInfo | null> {
  if (!code) return null;
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/tables/${encodeURIComponent(code)}`, { cache: 'no-store' });
    if (!res.ok) return null;
    const data = (await res.json()) as { table?: TableInfo };
    return data.table ?? null;
  } catch {
    return null;
  }
}

export default async function OrderPage({
  searchParams,
}: {
  searchParams: Promise<{ table?: string }>;
}) {
  const { table: tableCode } = await searchParams;
  const [{ items, categories }, table] = await Promise.all([getMenu(), getTable(tableCode)]);

  return (
    <>
      <Header />
      <main id="main">
        {table ? (
          <TableOrderFlow table={table} menu={items} categories={categories} />
        ) : (
          <OrderFlow menu={items} categories={categories} />
        )}
      </main>
      <Footer />
    </>
  );
}
