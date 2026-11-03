'use client';

import { useEffect, useState } from 'react';
import { MENU_ITEMS, MENU_CATEGORIES, type MenuItem } from '@/lib/content';
import type { OrderMenuItem } from '@/lib/order';

// The site is a static export on Firebase Hosting; Hosting rewrites /api/** to the
// `api` Cloud Function, so the browser fetches the LIVE admin menu same-origin.
// Falls back to the static site menu if the API is unreachable.

type ApiMenu = { items: OrderMenuItem[]; categories: string[] };

async function fetchMenu(): Promise<ApiMenu> {
  const res = await fetch('/api/menu', { cache: 'no-store' });
  if (!res.ok) throw new Error(`menu ${res.status}`);
  const data = (await res.json()) as ApiMenu;
  if (!data.items?.length) throw new Error('empty menu');
  return data;
}

/** Static site menu in the order-flow shape. */
export function fallbackOrderMenu(): ApiMenu {
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
  return { items, categories: Array.from(new Set(items.map((i) => i.category))) };
}

/** Live menu for the order flow (`null` while loading). */
export function useOrderMenu(): ApiMenu | null {
  const [menu, setMenu] = useState<ApiMenu | null>(null);
  useEffect(() => {
    let cancelled = false;
    fetchMenu()
      .catch(fallbackOrderMenu)
      .then((m) => !cancelled && setMenu(m));
    return () => {
      cancelled = true;
    };
  }, []);
  return menu;
}

/** Live menu for the public menu page (`null` while loading). */
export function useLiveMenu(): { items: MenuItem[]; categories: string[]; live: boolean } | null {
  const [menu, setMenu] = useState<{ items: MenuItem[]; categories: string[]; live: boolean } | null>(null);
  useEffect(() => {
    let cancelled = false;
    fetchMenu()
      .then((data) => ({
        items: data.items.map((m) => ({
          id: m.id,
          name: m.name,
          desc: m.description,
          price: m.price,
          rating: m.rating,
          tag: m.tag ?? '',
          category: m.category as MenuItem['category'],
          image: m.imageUrl,
        })),
        categories: data.categories ?? [...MENU_CATEGORIES],
        live: true,
      }))
      .catch(() => ({ items: MENU_ITEMS, categories: [...MENU_CATEGORIES], live: false }))
      .then((m) => !cancelled && setMenu(m));
    return () => {
      cancelled = true;
    };
  }, []);
  return menu;
}
