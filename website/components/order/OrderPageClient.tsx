'use client';

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import OrderFlow from './OrderFlow';
import TableOrderFlow, { type TableInfo } from './TableOrderFlow';
import { useOrderMenu } from '@/lib/menu-api';

// Resolve a scanned table QR code (?table=CODE) to its table. Returns null if the
// code is missing/invalid so the page falls back to the normal order flow.
function useTable(code: string | null): TableInfo | null | undefined {
  const [table, setTable] = useState<TableInfo | null | undefined>(code ? undefined : null);
  useEffect(() => {
    if (!code) return setTable(null);
    let cancelled = false;
    fetch(`/api/tables/${encodeURIComponent(code)}`, { cache: 'no-store' })
      .then((r) => (r.ok ? r.json() : {}))
      .then((d: { table?: TableInfo }) => !cancelled && setTable(d.table ?? null))
      .catch(() => !cancelled && setTable(null));
    return () => {
      cancelled = true;
    };
  }, [code]);
  return table;
}

export default function OrderPageClient() {
  const menu = useOrderMenu();
  const table = useTable(useSearchParams().get('table'));

  if (!menu || table === undefined) {
    return <p className="container py-40 text-center text-sm text-cream/60">Loading menu…</p>;
  }
  return table ? (
    <TableOrderFlow table={table} menu={menu.items} categories={menu.categories} />
  ) : (
    <OrderFlow menu={menu.items} categories={menu.categories} />
  );
}
