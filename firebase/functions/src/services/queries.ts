import { C, all, get, where, def, iso, isoDate, ms, sortBy, toDate, type Row } from '../lib/db';
import { formatCurrency, locale, local, localeTime, nowLocal, round, js, weekday } from '../lib/format';

/**
 * Server-side data access — port of Services/Queries.php (queries.ts). Returns the exact view
 * shapes the web admin and the mobile API return: same keys and nesting, numbers as numbers,
 * optional fields omitted when absent, dates as JS ISO strings.
 */

export const TYPE_LABELS: Record<string, string> = { DINE_IN: 'Dine-in', DELIVERY: 'Delivery', PICKUP: 'Pick-up' };
const OPEN_HOUR = 10;
const CLOSE_HOUR = 22;
const OCCUPIED_TOO_LONG_MIN = 120;
const LARGE_BILL_THRESHOLD = 300;

const byCreatedDesc = (a: Row, b: Row) => ms(b.createdAt) - ms(a.createdAt);
const byCreatedAsc = (a: Row, b: Row) => ms(a.createdAt) - ms(b.createdAt);

/** `arr.sort((a, b) => (a[key] < b[key] ? 1 : -1))` as V8 runs it: descending, ties in reverse input order. */
function sortDescByKey<T extends Record<string, unknown>>(items: T[], key: keyof T): T[] {
  return [...items].reverse().sort((a, b) => (String(b[key]) > String(a[key]) ? 1 : String(b[key]) < String(a[key]) ? -1 : 0));
}

/** startOfToday - (days - 1) days, in server-local time. */
const rangeStart = (days: number): number => nowLocal().startOf('day').toMillis() - (days - 1) * 86_400_000;

async function outletNameMap(): Promise<Record<string, string>> {
  return Object.fromEntries((await all(C.outlets)).map((o) => [o.id, o.name]));
}

const lines = (items: Row[] = []) => items.map((it) => ({ name: it.name, qty: Number(it.qty), price: Number(it.price) }));

export async function getInventory() {
  return sortBy(await all(C.inventoryItems), 'name').map((r) => ({
    id: r.id,
    name: r.name,
    category: r.category,
    unit: r.unit,
    quantity: Number(r.quantity),
    reorderLevel: Number(r.reorderLevel),
    costPerUnit: Number(r.costPerUnit),
    supplier: r.supplier ?? '',
  }));
}

async function categoryNames(): Promise<Record<string, string>> {
  return Object.fromEntries((await all(C.categories)).map((c) => [c.id, c.name]));
}

export async function getMenuItems() {
  const cats = await categoryNames();
  return sortBy(await all(C.menuItems), 'name').map((r) => ({
    id: r.id,
    name: r.name,
    description: r.description,
    price: Number(r.price),
    rating: Number(r.rating),
    tag: r.tag ?? '',
    category: cats[r.categoryId],
    imageUrl: r.imageUrl,
    available: !!r.available,
  }));
}

export async function getDashboardConfig() {
  const c = await get(C.dashboardConfig, 'default');
  let topCategories = null;
  if (c?.topCategories) {
    try { topCategories = JSON.parse(c.topCategories); } catch { topCategories = null; }
  }
  return { trendingItemId: c?.trendingItemId ?? null, topCategories };
}

export async function getMenuCategories() {
  const items = await all(C.menuItems);
  return sortBy(await all(C.categories), 'name').map((c) => ({
    id: c.id,
    name: c.name,
    active: !!c.active,
    itemCount: items.filter((i) => i.categoryId === c.id).length,
  }));
}

export async function getOrders() {
  const names = await outletNameMap();
  return (await all(C.orders)).sort(byCreatedDesc).map((o) => def({
    id: o.id,
    number: o.number,
    type: o.type,
    status: o.status,
    channel: o.channel,
    paymentMethod: o.paymentMethod ?? 'CASH',
    outlet: names[o.outletId] ?? o.outletId,
    customer: o.customerName,
    customerEmail: o.customerEmail,
    customerPhone: o.customerPhone,
    items: lines(o.items),
    total: Number(o.total),
    scheduleType: o.scheduleType,
    scheduleDate: o.scheduleDate ? iso(o.scheduleDate) : null,
    scheduleTime: o.scheduleTime,
    notes: o.notes,
    tableNumber: o.tableNumber,
    paymentProvider: o.paymentProvider,
    razorpayPaymentId: o.razorpayPaymentId,
    createdAt: iso(o.createdAt),
  }));
}

export async function getTables() {
  const orders = await all(C.orders);
  return sortBy(await all(C.tables), 'number').map((t) => def({
    id: t.id,
    number: t.number,
    name: t.name,
    code: t.code,
    status: t.status,
    orderCount: orders.filter((o) => o.tableId === t.id).length,
    createdAt: iso(t.createdAt),
  }));
}

export async function getGiftCards() {
  return (await all(C.giftCards)).sort(byCreatedDesc).map((g) => def({
    id: g.id,
    code: g.code,
    kind: g.kind,
    customerName: g.customerName,
    customerEmail: g.customerEmail,
    amount: Number(g.amount),
    message: g.message,
    expiryDate: g.expiryDate ? isoDate(g.expiryDate) : null,
    paymentStatus: g.paymentStatus,
    status: g.status,
    paymentProvider: g.paymentProvider,
    razorpayPaymentId: g.razorpayPaymentId,
    createdAt: iso(g.createdAt),
  }));
}

// ---- Floor plan / table sessions ----

export async function getFloorTables() {
  const tables = sortBy(await all(C.tables), 'number');
  const open = (await where(C.tableSessions, 'status', 'OPEN')).sort((a, b) => ms(b.openedAt) - ms(a.openedAt));
  const latest: Record<string, Row> = {};
  for (const s of open) latest[s.tableId] ??= s;
  const sessionIds = Object.values(latest).map((s) => s.id);
  const orders = await where(C.orders, 'sessionId', sessionIds);
  const waiters = Object.fromEntries((await all(C.employees)).map((e) => [e.id, e.name]));

  return tables.map((t) => {
    const s = latest[t.id];
    const so = s ? orders.filter((o) => o.sessionId === s.id) : [];
    return {
      ...def({ id: t.id, number: t.number, name: t.name, capacity: Number(t.capacity), status: t.status, state: t.state }),
      session: s ? def({
        id: s.id,
        openedAt: iso(s.openedAt),
        customerCount: Number(s.customerCount),
        customerName: s.customerName,
        waiterName: s.waiterId ? waiters[s.waiterId] : null,
        currentBill: so.reduce((sum, o) => sum + Number(o.total), 0),
        orderCount: so.length,
      }) : null,
    };
  });
}

export async function getTablePos(tableId: string) {
  const table = await get(C.tables, tableId);
  if (!table) return { table: null, session: null };
  const open = (await where(C.tableSessions, 'tableId', tableId)).filter((s) => s.status === 'OPEN');
  const s = open[0];
  const posTable = def({ id: table.id, number: table.number, name: table.name, capacity: Number(table.capacity), state: table.state });
  if (!s) return { table: posTable, session: null };

  const orders = (await where(C.orders, 'sessionId', s.id)).sort(byCreatedAsc);
  const payRows = (await where(C.payments, 'sessionId', s.id)).sort(byCreatedAsc);
  const waiter = s.waiterId ? await get(C.employees, s.waiterId) : null;

  // Aggregate identical items (by menu item) across all session orders.
  const byItem = new Map<string, { menuItemId: string; name: string; qty: number; price: number }>();
  for (const o of orders) {
    for (const it of o.items ?? []) {
      const cur = byItem.get(it.menuItemId);
      if (cur) cur.qty += Number(it.qty);
      else byItem.set(it.menuItemId, { menuItemId: it.menuItemId, name: it.name, qty: Number(it.qty), price: Number(it.price) });
    }
  }
  const payments = payRows.map((p) => ({ amount: Number(p.amount), method: p.method, createdAt: iso(p.createdAt) }));
  const paid = payments.reduce((sum, p) => sum + p.amount, 0);
  const total = Number(s.total);

  return {
    table: posTable,
    session: def({
      id: s.id,
      openedAt: iso(s.openedAt),
      customerCount: Number(s.customerCount),
      customerName: s.customerName,
      waiterName: waiter?.name,
      lines: [...byItem.values()],
      orders: orders.map((o) => ({ id: o.id, number: o.number, createdAt: iso(o.createdAt), items: lines(o.items) })),
      subtotal: Number(s.subtotal),
      discount: Number(s.discount),
      tax: Number(s.tax),
      serviceCharge: Number(s.serviceCharge),
      tip: Number(s.tip),
      total,
      payments,
      paid,
      remaining: Math.max(0, total - paid),
    }),
  };
}

// ---- Table analytics ----

export async function getTableAnalytics(days = 1) {
  const nowMs = Date.now();
  const start = rangeStart(days);
  const tables = await all(C.tables);
  const sessions = (await all(C.tableSessions)).filter((s) => ms(s.openedAt) >= start);
  const sessionIds = new Set(sessions.map((s) => s.id));
  const allOrders = await all(C.orders);
  const sessOrders = allOrders.filter((o) => o.sessionId && sessionIds.has(o.sessionId));
  const ordersCount = (sid: string) => sessOrders.filter((o) => o.sessionId === sid).length;
  const orderItems = sessOrders.flatMap((o) => o.items ?? []);
  const payments = (await all(C.payments)).filter((p) => sessionIds.has(p.sessionId));

  const live = { total: tables.length, available: 0, occupied: 0, reserved: 0, cleaning: 0, outOfService: 0 };
  for (const t of tables) {
    if (t.state === 'AVAILABLE') live.available++;
    else if (t.state === 'OCCUPIED') live.occupied++;
    else if (t.state === 'RESERVED') live.reserved++;
    else if (t.state === 'CLEANING') live.cleaning++;
    else if (t.state === 'OUT_OF_SERVICE') live.outOfService++;
  }

  const durationMin = (s: Row) => Math.max(0, ((s.closedAt ? ms(s.closedAt) : nowMs) - ms(s.openedAt)) / 60000);

  const tableById = new Map(tables.map((t) => [t.id, t]));
  const agg: Record<string, { sessions: number; customers: number; orders: number; revenue: number; occupiedMin: number; seatRatioSum: number }> = {};
  for (const s of sessions) {
    const cur = agg[s.tableId] ?? { sessions: 0, customers: 0, orders: 0, revenue: 0, occupiedMin: 0, seatRatioSum: 0 };
    const cap = Number(tableById.get(s.tableId)?.capacity ?? 4);
    cur.sessions += 1;
    cur.customers += Number(s.customerCount);
    cur.orders += ordersCount(s.id);
    cur.revenue += Number(s.total);
    cur.occupiedMin += durationMin(s);
    cur.seatRatioSum += Math.min(1, Number(s.customerCount) / Math.max(1, cap));
    agg[s.tableId] = cur;
  }

  const operatingMin = (CLOSE_HOUR - OPEN_HOUR) * 60 * days;
  const perTable = tables.map((t) => {
    const a = agg[t.id];
    const n = a?.sessions ?? 0;
    const revenue = a?.revenue ?? 0;
    return def({
      id: t.id,
      number: t.number as string,
      name: t.name,
      sessions: n,
      customers: a?.customers ?? 0,
      orders: a?.orders ?? 0,
      revenue,
      avgBill: n ? round(revenue / n) : 0,
      avgDiningMinutes: n ? round(a!.occupiedMin / n) : 0,
      occupiedMinutes: round(a?.occupiedMin ?? 0),
      occupancyPct: Math.min(100, round(((a?.occupiedMin ?? 0) / operatingMin) * 100)),
      utilizationPct: n ? round((a!.seatRatioSum / n) * 100) : 0,
    });
  });

  const totalSessions = sessions.length;
  const customers = sessions.reduce((s, x) => s + Number(x.customerCount), 0);
  const orders = sessions.reduce((s, x) => s + ordersCount(x.id), 0);
  const revenue = sessions.reduce((s, x) => s + Number(x.total), 0);
  const diningTotal = sessions.reduce((s, x) => s + durationMin(x), 0);
  const summary = {
    sessions: totalSessions,
    customers,
    orders,
    revenue,
    avgBill: totalSessions ? round(revenue / totalSessions) : 0,
    avgCustomersPerTable: totalSessions ? round((customers / totalSessions) * 10) / 10 : 0,
    avgDiningMinutes: totalSessions ? round(diningTotal / totalSessions) : 0,
  };

  type PT = (typeof perTable)[number];
  const withSessions = perTable.filter((t) => t.sessions > 0);
  const pick = (arr: PT[], key: (t: PT) => number, fmt: (t: PT) => string, max = true) => {
    if (!arr.length) return null;
    let best = arr[0];
    for (const t of arr.slice(1)) if (max ? key(t) > key(best) : key(t) < key(best)) best = t;
    return { number: best.number, value: fmt(best) };
  };
  const money = (n: number) => '$' + locale(n);
  const top = {
    highestRevenue: pick(withSessions, (t) => t.revenue, (t) => money(t.revenue)),
    mostUsed: pick(withSessions, (t) => t.sessions, (t) => `${t.sessions} sessions`),
    mostCustomers: pick(withSessions, (t) => t.customers, (t) => `${t.customers} guests`),
    highestAvgBill: pick(withSessions, (t) => t.avgBill, (t) => money(t.avgBill)),
    longestOccupied: pick(withSessions, (t) => t.occupiedMinutes, (t) => `${t.occupiedMinutes} min`),
    fastestTurnover: pick(withSessions, (t) => t.avgDiningMinutes, (t) => `${t.avgDiningMinutes} min`, false),
  };
  const least = {
    leastUsed: pick(perTable, (t) => t.sessions, (t) => `${t.sessions} sessions`, false),
    lowestRevenue: pick(perTable, (t) => t.revenue, (t) => money(t.revenue), false),
    lowestOccupancy: pick(perTable, (t) => t.occupancyPct, (t) => `${t.occupancyPct}%`, false),
  };

  const hourCounts = Array(24).fill(0);
  const dayCounts = Array(7).fill(0);
  for (const s of sessions) {
    const l = local(s.openedAt);
    hourCounts[l.hour]++;
    dayCounts[weekday(l)]++;
  }
  const busyHours = [];
  for (let h = OPEN_HOUR; h < CLOSE_HOUR; h++) busyHours.push({ hour: h, label: `${h % 12 || 12}${h < 12 ? 'AM' : 'PM'}`, sessions: hourCounts[h] });
  let peakH = OPEN_HOUR;
  for (let h = 0; h < 24; h++) if (hourCounts[h] > hourCounts[peakH]) peakH = h;
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  let peakD = 0;
  for (let d = 0; d < 7; d++) if (dayCounts[d] > dayCounts[peakD]) peakD = d;
  const peakHour = totalSessions ? `${peakH % 12 || 12}:00 ${peakH < 12 ? 'AM' : 'PM'}` : '—';
  const peakDay = totalSessions ? DAYS[peakD] : '—';

  const itemQty = new Map<string, number>();
  for (const it of orderItems) itemQty.set(it.name, (itemQty.get(it.name) ?? 0) + Number(it.qty));
  const favouriteItems = [...itemQty].map(([name, qty]) => ({ name, qty })).sort((a, b) => b.qty - a.qty).slice(0, 5);
  const methodCount = new Map<string, number>();
  for (const p of payments) methodCount.set(p.method, (methodCount.get(p.method) ?? 0) + 1);
  const paymentMix = [...methodCount].map(([method, count]) => ({ method, count })).sort((a, b) => b.count - a.count);

  return {
    days,
    live,
    summary,
    perTable,
    top,
    least,
    busyHours,
    peakHour,
    peakDay,
    customer: { served: customers, avgSpend: customers ? round(revenue / customers) : 0, favouriteItems, paymentMix },
  };
}

export async function getTableHistory(tableId: string, days = 30) {
  const table = await get(C.tables, tableId);
  if (!table) return { table: null, sessions: [] };
  const nowMs = Date.now();
  const start = rangeStart(days);
  const rows = (await where(C.tableSessions, 'tableId', tableId)).filter((s) => ms(s.openedAt) >= start).sort((a, b) => ms(b.openedAt) - ms(a.openedAt));
  const orders = await where(C.orders, 'sessionId', rows.map((r) => r.id));
  const waiters = Object.fromEntries((await all(C.employees)).map((e) => [e.id, e.name]));

  const sessions = rows.map((s) => {
    const byName = new Map<string, { name: string; qty: number; price: number }>();
    for (const o of orders.filter((o) => o.sessionId === s.id)) {
      for (const it of o.items ?? []) {
        const cur = byName.get(it.name);
        if (cur) cur.qty += Number(it.qty);
        else byName.set(it.name, { name: it.name, qty: Number(it.qty), price: Number(it.price) });
      }
    }
    const end = s.closedAt ? ms(s.closedAt) : nowMs;
    return def({
      id: s.id,
      openedAt: iso(s.openedAt),
      closedAt: s.closedAt ? iso(s.closedAt) : null,
      durationMinutes: Math.max(0, round((end - ms(s.openedAt)) / 60000)),
      customerCount: Number(s.customerCount),
      customerName: s.customerName,
      waiterName: s.waiterId ? waiters[s.waiterId] : null,
      items: [...byName.values()],
      subtotal: Number(s.subtotal),
      discount: Number(s.discount),
      tax: Number(s.tax),
      serviceCharge: Number(s.serviceCharge),
      tip: Number(s.tip),
      total: Number(s.total),
      paymentMethod: s.paymentMethod,
      status: s.status,
    });
  });
  return { table: def({ id: table.id, number: table.number, name: table.name }), sessions };
}

export async function getMergeTargets(excludeTableId: string) {
  const tables = new Map((await all(C.tables)).map((t) => [t.id, t]));
  const open = (await where(C.tableSessions, 'status', 'OPEN')).filter((s) => s.tableId !== excludeTableId && tables.has(s.tableId));
  return sortBy(open.map((s) => ({ tableId: s.tableId as string, sessionId: s.id, number: tables.get(s.tableId)!.number as string })), 'number');
}

export async function getWaiterOptions() {
  return sortBy((await all(C.employees)).filter((e) => e.active), 'name').map((e) => ({ id: e.id, name: e.name }));
}

/** Unified payments feed: paid orders, gift-card purchases, and POS session payments. */
export async function getTransactions() {
  const orders = (await all(C.orders)).filter((o) => o.paymentMethod != null).sort(byCreatedDesc).slice(0, 250);
  const gifts = (await all(C.giftCards)).filter((g) => g.paymentStatus === 'PAID').sort(byCreatedDesc).slice(0, 250);
  const payments = (await all(C.payments)).sort(byCreatedDesc).slice(0, 250);
  const sessions = new Map((await all(C.tableSessions)).map((s) => [s.id, s]));
  const tables = new Map((await all(C.tables)).map((t) => [t.id, t]));
  const gatewayLabel = (p: string | null) => ({ razorpay: 'Razorpay', stripe: 'Stripe', paypal: 'PayPal' } as Record<string, string>)[p ?? ''] ?? null;

  const txns: Record<string, unknown>[] = [];
  for (const o of orders) {
    txns.push(def({
      id: `o-${o.id}`, source: 'Order', reference: o.number, customer: o.customerName, amount: Number(o.total),
      method: gatewayLabel(o.paymentProvider) ?? o.paymentMethod ?? '—', paymentId: o.razorpayPaymentId, status: o.status, date: iso(o.createdAt),
    }));
  }
  for (const g of gifts) {
    txns.push(def({
      id: `g-${g.id}`, source: 'Gift Card', reference: g.code, customer: g.customerName, amount: Number(g.amount),
      method: gatewayLabel(g.paymentProvider) ?? 'Online', paymentId: g.razorpayPaymentId, status: g.status, date: iso(g.createdAt),
    }));
  }
  for (const p of payments) {
    const s = sessions.get(p.sessionId);
    txns.push({
      id: `p-${p.id}`, source: 'Table', reference: `Table ${tables.get(s?.tableId)?.number}`, customer: s?.customerName ?? '—',
      amount: Number(p.amount), method: p.method, status: 'PAID', date: iso(p.createdAt),
    });
  }
  return sortDescByKey(txns, 'date');
}

export async function getReservations() {
  return (await all(C.reservations)).sort(byCreatedDesc).map((r) => def({
    id: r.id,
    reference: r.reference,
    kind: r.kind,
    status: r.status,
    date: isoDate(r.date),
    name: r.name,
    email: r.email,
    phone: r.phone,
    time: r.time,
    guests: r.guests != null ? Number(r.guests) : null,
    occasion: r.occasion,
    requests: r.requests,
    eventType: r.eventType,
    guestRange: r.guestRange,
    space: r.space,
    company: r.company,
    message: r.message,
    createdAt: iso(r.createdAt),
  }));
}

export async function getOutlets() {
  const metrics = (await all(C.outletMetrics)).sort((a, b) => ms(a.periodStart) - ms(b.periodStart));
  return sortBy(await all(C.outlets), 'name').map((o) => ({
    id: o.id,
    name: o.name,
    location: o.location ?? '',
    address: o.address ?? '',
    phone: o.phone ?? '',
    manager: o.manager ?? '',
    isActive: !!o.isActive,
    weekly: metrics.filter((m) => m.outletId === o.id).map((m, i) => ({ week: `W${i + 1}`, revenue: Number(m.revenue), cost: Number(m.operationalCost) })),
  }));
}

export async function getEmployees() {
  const names = await outletNameMap();
  return sortBy(await all(C.employees), 'name').map((e) => def({
    id: e.id,
    name: e.name,
    role: e.role,
    outlet: names[e.outletId] ?? e.outletId,
    email: e.email ?? '',
    phone: e.phone,
    active: !!e.active,
    status: e.status,
    createdAt: iso(e.createdAt),
  }));
}

export async function getCustomers() {
  const orders = await all(C.orders);
  const reservations = await all(C.reservations);
  return sortBy(await all(C.customers), 'name').map((c) => {
    const co = orders.filter((o) => o.customerId === c.id).map((o) => ({ number: o.number, total: Number(o.total), status: o.status, date: iso(o.createdAt)! }));
    const cr = reservations.filter((r) => r.customerId === c.id).map((r) => ({ reference: r.reference, kind: r.kind, status: r.status, date: iso(r.date)! }));
    const totalSpend = co.reduce((s, o) => (o.status !== 'CANCELED' ? s + o.total : s), 0);
    const dates = [...co.map((o) => o.date), ...cr.map((r) => r.date)].sort();
    return def({
      id: c.id,
      name: c.name,
      email: c.email,
      phone: c.phone,
      address: c.address,
      status: c.status,
      orders: co,
      reservations: cr,
      totalSpend,
      lastActivity: dates.length ? dates[dates.length - 1] : '',
      createdAt: iso(c.createdAt),
    });
  });
}

// ---- Dashboard aggregation ----

const pct = (part: number, total: number) => (total ? round((part / total) * 100) : 0);
const formatHour = (h: number) => `${h % 12 || 12}.00 ${h < 12 ? 'AM' : 'PM'}`;

export async function getDashboardData() {
  const orders = (await all(C.orders)).sort(byCreatedDesc);
  const cats = await categoryNames();
  const menu: Row[] = (await all(C.menuItems)).map((m) => ({ ...m, categoryName: cats[m.categoryId] }));
  const outlets = sortBy(await all(C.outlets), 'name');
  const metrics = (await all(C.outletMetrics)).sort((a, b) => ms(a.periodStart) - ms(b.periodStart));
  const employees = await all(C.employees);
  const dashCfg = await get(C.dashboardConfig, 'default');

  const menuByName = new Map<string, Row>();
  const menuById = new Map<string, Row>();
  for (const m of menu) { menuByName.set(m.name, m); menuById.set(m.id, m); }
  const catImageAll = new Map<string, string>();
  for (const m of menu) if (!catImageAll.has(m.categoryName)) catImageAll.set(m.categoryName, m.imageUrl);

  const completed = orders.filter((o) => o.status === 'COMPLETED');
  const canceled = orders.filter((o) => o.status === 'CANCELED');
  const revenue = completed.reduce((s, o) => s + Number(o.total), 0);
  const kpis = [
    { key: 'orders', label: 'Total Orders', value: locale(orders.length), delta: 10, accent: true },
    { key: 'delivered', label: 'Total Delivered', value: locale(completed.length), delta: 7.5 },
    { key: 'canceled', label: 'Canceled Order', value: locale(canceled.length), delta: -3.5 },
    { key: 'revenue', label: 'Total Revenue', value: formatCurrency(revenue), delta: 7.5 },
  ];

  const qtyByItem = new Map<string, number>();
  for (const o of orders) for (const it of o.items ?? []) qtyByItem.set(it.name, (qtyByItem.get(it.name) ?? 0) + Number(it.qty));
  let trendingName: string = menu[0]?.name ?? '';
  let trendingQty = 0;
  for (const [name, q] of qtyByItem) if (q > trendingQty) { trendingQty = q; trendingName = name; }
  const tItem = menuByName.get(trendingName);
  let trending = {
    name: trendingName,
    subtitle: tItem ? (tItem.tag ?? 'Popular') : 'Popular',
    rating: tItem ? Number(tItem.rating) : 4.8,
    orders: trendingQty,
    price: tItem ? Number(tItem.price) : 0,
    image: tItem?.imageUrl ?? '',
  };
  if (dashCfg?.trendingItemId) {
    const mi = menuById.get(dashCfg.trendingItemId);
    if (mi) trending = { name: mi.name, subtitle: mi.tag ?? 'Featured', rating: Number(mi.rating), orders: qtyByItem.get(mi.name) ?? 0, price: Number(mi.price), image: mi.imageUrl };
  }

  const outletSeries = outlets.map((o) => {
    const om = metrics.filter((m) => m.outletId === o.id);
    const m = om[om.length - 1];
    return { outlet: o.name as string, sells: m ? Number(m.revenue) : 0, cost: m ? Number(m.operationalCost) : 0 };
  });
  const revenueTotal = formatCurrency(outletSeries.reduce((s, o) => s + o.sells, 0));

  const qtyByCat = new Map<string, number>();
  const imageByCat = new Map<string, string>();
  for (const o of orders) {
    for (const it of o.items ?? []) {
      const mi = menuByName.get(it.name);
      if (!mi) continue;
      qtyByCat.set(mi.categoryName, (qtyByCat.get(mi.categoryName) ?? 0) + Number(it.qty));
      if (!imageByCat.has(mi.categoryName)) imageByCat.set(mi.categoryName, mi.imageUrl);
    }
  }
  const totalCatQty = [...qtyByCat.values()].reduce((a, b) => a + b, 0);
  let topCategories: Record<string, unknown>[] = [...qtyByCat].sort((a, b) => b[1] - a[1]).slice(0, 3)
    .map(([name, q]) => ({ name, percent: pct(q, totalCatQty), image: imageByCat.get(name) ?? '' }));
  if (dashCfg?.topCategories) {
    try {
      const parsed = JSON.parse(dashCfg.topCategories);
      if (Array.isArray(parsed) && parsed.length) {
        topCategories = parsed.slice(0, 3).map((p: Record<string, unknown>) => def({ name: p.name, percent: p.percent, image: catImageAll.get(String(p.name ?? '')) ?? '' }));
      }
    } catch { /* keep computed */ }
  }

  const countByStatus: Record<string, number> = {};
  for (const e of employees) countByStatus[e.status] = (countByStatus[e.status] ?? 0) + 1;
  const employee = {
    total: employees.length,
    segments: [
      { label: 'On Duty', value: countByStatus.ON_DUTY ?? 0, color: 'var(--color-success)' },
      { label: 'On Break', value: countByStatus.ON_BREAK ?? 0, color: 'var(--color-warn)' },
      { label: 'Absent', value: countByStatus.ABSENT ?? 0, color: 'var(--color-danger)' },
    ],
  };

  const hourCounts = new Map<number, number>();
  for (const o of orders) { const h = local(o.createdAt).hour; hourCounts.set(h, (hourCounts.get(h) ?? 0) + 1); }
  let peak = 17;
  let peakN = -1;
  for (const [h, n] of hourCounts) if (n > peakN) { peakN = n; peak = h; }
  const cash = orders.filter((o) => o.paymentMethod === 'CASH').length;
  const card = orders.filter((o) => o.paymentMethod === 'CARD').length;
  const online = orders.filter((o) => o.paymentMethod === 'ONLINE').length;
  const payTotal = cash + card + online;
  const ordersSum = orders.reduce((s, o) => s + Number(o.total), 0);
  const pos = {
    totalSales: formatCurrency(revenue),
    salesDelta: 12,
    totalBills: orders.length,
    avgValue: formatCurrency(orders.length ? round(ordersSum / orders.length) : 0),
    peakHour: formatHour(peak),
    payment: { cash: pct(cash, payTotal), card: pct(card, payTotal), online: pct(online, payTotal) },
  };

  const recentOrders = orders.slice(0, 3).map((o, i) => {
    const firstItem = (o.items ?? [])[0];
    const mi = firstItem ? menuByName.get(firstItem.name) : undefined;
    return {
      line: String(i + 1).padStart(2, '0'),
      orderId: o.number,
      customer: o.customerName,
      type: TYPE_LABELS[o.type] ?? o.type,
      status: o.status,
      price: Number(o.total),
      image: mi?.imageUrl ?? '',
    };
  });

  const n = orders.length;
  const salesTypes = [
    { label: 'Dine-in', percent: pct(orders.filter((o) => o.type === 'DINE_IN').length, n) },
    { label: 'Delivery', percent: pct(orders.filter((o) => o.type === 'DELIVERY').length, n) },
    { label: 'Pick-up', percent: pct(orders.filter((o) => o.type === 'PICKUP').length, n) },
  ];

  let active = outletSeries[0];
  for (const o of outletSeries) if (o.cost > (active?.cost ?? -1)) active = o;

  return { kpis, trending, outletSeries, outletActive: active?.outlet ?? '', revenueTotal, topCategories, employee, pos, recentOrders, salesTypes };
}

// ---- Reports ----

export async function getReportsData() {
  const orders = await all(C.orders);
  const cats = await categoryNames();
  const outletName = await outletNameMap();
  const catByItem = new Map<string, string>();
  for (const m of await all(C.menuItems)) catByItem.set(m.name, cats[m.categoryId]);

  const valid = orders.filter((o) => o.status !== 'CANCELED');
  const revenue = valid.reduce((s, o) => s + Number(o.total), 0);
  const itemsSold = valid.reduce((s, o) => s + (o.items ?? []).reduce((n: number, it: Row) => n + Number(it.qty), 0), 0);
  const summary = { revenue, orders: orders.length, itemsSold, avgOrder: valid.length ? round(revenue / valid.length) : 0 };

  const byOutlet = new Map<string, { revenue: number; orders: number }>();
  for (const o of valid) {
    const name = outletName[o.outletId] ?? o.outletId;
    const cur = byOutlet.get(name) ?? { revenue: 0, orders: 0 };
    cur.revenue += Number(o.total);
    cur.orders += 1;
    byOutlet.set(name, cur);
  }
  const collator = new Intl.Collator('en-US');
  const revenueByOutlet = [...byOutlet].map(([outlet, v]) => ({ outlet, ...v })).sort((a, b) => collator.compare(a.outlet, b.outlet));

  const itemAgg = new Map<string, { qty: number; revenue: number }>();
  const catAgg = new Map<string, { qty: number; revenue: number }>();
  for (const o of valid) {
    for (const it of o.items ?? []) {
      const lineRev = Number(it.qty) * Number(it.price);
      const i = itemAgg.get(it.name) ?? { qty: 0, revenue: 0 };
      i.qty += Number(it.qty);
      i.revenue += lineRev;
      itemAgg.set(it.name, i);
      const cat = catByItem.get(it.name) ?? 'Other';
      const c = catAgg.get(cat) ?? { qty: 0, revenue: 0 };
      c.qty += Number(it.qty);
      c.revenue += lineRev;
      catAgg.set(cat, c);
    }
  }
  const topItems = [...itemAgg].map(([name, v]) => ({ name, ...v })).sort((a, b) => b.qty - a.qty).slice(0, 8);
  const categoryMix = [...catAgg].map(([category, v]) => ({ category, ...v })).sort((a, b) => b.revenue - a.revenue);
  const typeCount = (t: string) => orders.filter((o) => o.type === t).length;
  const payCount = (m: string) => valid.filter((o) => o.paymentMethod === m).length;

  return {
    summary,
    revenueByOutlet,
    topItems,
    categoryMix,
    orderTypes: [
      { type: 'Dine-in', count: typeCount('DINE_IN') },
      { type: 'Delivery', count: typeCount('DELIVERY') },
      { type: 'Pick-up', count: typeCount('PICKUP') },
    ],
    paymentMix: [
      { method: 'Cash', count: payCount('CASH') },
      { method: 'Card', count: payCount('CARD') },
      { method: 'Online', count: payCount('ONLINE') },
    ],
  };
}

// ---- Settings & notifications ----

export async function getProfile() {
  const p = await get(C.restaurantProfile, 'default');
  return {
    name: p?.name ?? 'Go4Foodie',
    currency: p?.currency ?? 'USD',
    timezone: p?.timezone ?? 'America/New_York',
    address: p?.address ?? '',
    phone: p?.phone ?? '',
    email: p?.email ?? '',
  };
}

export async function getUsers() {
  return sortBy(await all(C.users), 'name').map((u) => ({ id: u.id, name: u.name, email: u.email, role: u.role }));
}

export async function getNotifications() {
  const nowIso = new Date().toISOString();
  const nowMs = Date.now();
  const orders = (await all(C.orders)).sort(byCreatedDesc).slice(0, 6);
  const reservations = (await where(C.reservations, 'status', 'REQUESTED')).sort(byCreatedDesc).slice(0, 6);
  const inventory = await all(C.inventoryItems);
  const tables = await all(C.tables);
  const tableNo = new Map(tables.map((t) => [t.id, t.number]));
  const stateTables = tables.filter((t) => t.state === 'CLEANING' || t.state === 'WAITING_PAYMENT');
  const openSessions = await where(C.tableSessions, 'status', 'OPEN');

  const tableAlerts: { id: string; type: string; title: string; detail: string; time: string }[] = [];
  for (const t of stateTables) {
    const cleaning = t.state === 'CLEANING';
    tableAlerts.push({
      id: `t-${t.id}`, type: 'table',
      title: cleaning ? `Table ${t.number} needs cleaning` : `Table ${t.number} payment pending`,
      detail: cleaning ? 'Mark available once cleaned.' : 'Awaiting checkout.',
      time: nowIso,
    });
  }
  for (const s of openSessions) {
    if (nowMs - ms(s.openedAt) > OCCUPIED_TOO_LONG_MIN * 60_000) {
      tableAlerts.push({ id: `tl-${s.id}`, type: 'table', title: `Table ${tableNo.get(s.tableId)} occupied 2h+`, detail: `Open since ${localeTime(s.openedAt)}`, time: iso(s.openedAt)! });
    }
  }
  for (const s of openSessions) {
    if (Number(s.total) >= LARGE_BILL_THRESHOLD) {
      tableAlerts.push({ id: `tb-${s.id}`, type: 'table', title: `Large bill at Table ${tableNo.get(s.tableId)}`, detail: `${formatCurrency(Number(s.total))} running`, time: nowIso });
    }
  }

  const items: typeof tableAlerts = [];
  for (const o of orders) items.push({ id: `o-${o.id}`, type: 'order', title: `New order ${o.number}`, detail: `${o.customerName} · ${formatCurrency(Number(o.total))}`, time: iso(o.createdAt)! });
  for (const r of reservations) items.push({ id: `r-${r.id}`, type: 'reservation', title: `Reservation request ${r.reference}`, detail: `${r.name} · ${r.kind === 'TABLE' ? 'Table booking' : 'Private event'}`, time: iso(r.createdAt)! });
  for (const i of inventory) {
    if (Number(i.quantity) <= Number(i.reorderLevel)) {
      items.push({ id: `i-${i.id}`, type: 'stock', title: `Low stock: ${i.name}`, detail: `${js(Number(i.quantity))} ${i.unit} left (reorder at ${js(Number(i.reorderLevel))})`, time: iso(i.updatedAt)! });
    }
  }
  items.push(...tableAlerts);
  return sortDescByKey(items, 'time');
}

export async function getAuditLogs(limit = 150) {
  return (await all(C.auditLogs)).sort(byCreatedDesc).slice(0, limit).map((r) => def({
    id: r.id,
    action: r.action,
    entity: r.entity,
    entityId: r.entityId,
    detail: r.detail,
    userName: r.userName,
    createdAt: iso(r.createdAt),
  }));
}

export async function getAttentionCount(): Promise<number> {
  const requested = (await where(C.reservations, 'status', 'REQUESTED')).length;
  const lowStock = (await all(C.inventoryItems)).filter((i) => Number(i.quantity) <= Number(i.reorderLevel)).length;
  const tableAttention = (await all(C.tables)).filter((t) => t.state === 'CLEANING' || t.state === 'WAITING_PAYMENT').length;
  return requested + lowStock + tableAttention;
}

export { toDate };
