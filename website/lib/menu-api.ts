import { ADMIN_API_URL } from '@/lib/admin-api';
import { MENU_ITEMS, MENU_CATEGORIES, type MenuItem } from '@/lib/content';

// Fetch the LIVE menu from the admin panel (only available items in active
// categories) so the public/QR menu always reflects the latest admin data.
// Falls back to the static site menu if the admin API is unreachable.
export async function getLiveMenu(): Promise<{ items: MenuItem[]; categories: string[]; live: boolean }> {
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/menu`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`menu ${res.status}`);
    const data = (await res.json()) as {
      items: { id: string; name: string; description: string; price: number; rating: number; tag: string; category: string; imageUrl: string }[];
      categories: string[];
    };
    if (!data.items?.length) throw new Error('empty menu');

    const items: MenuItem[] = data.items.map((m) => ({
      id: m.id,
      name: m.name,
      desc: m.description,
      price: m.price,
      rating: m.rating,
      tag: m.tag ?? '',
      category: m.category as MenuItem['category'],
      image: m.imageUrl,
    }));
    return { items, categories: data.categories ?? [...MENU_CATEGORIES], live: true };
  } catch {
    return { items: MENU_ITEMS, categories: [...MENU_CATEGORIES], live: false };
  }
}
