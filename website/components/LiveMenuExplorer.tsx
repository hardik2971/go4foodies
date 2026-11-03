'use client';

import MenuExplorer from './MenuExplorer';
import { useLiveMenu } from '@/lib/menu-api';

/** Menu explorer fed by the live admin menu (QR scans must reflect live changes). */
export default function LiveMenuExplorer() {
  const menu = useLiveMenu();
  if (!menu) {
    return <p className="container py-24 text-center text-sm text-cream/60">Loading menu…</p>;
  }
  return <MenuExplorer items={menu.items} categories={menu.categories} />;
}
