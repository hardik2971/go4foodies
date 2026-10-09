// Helpers for the operations pages (dashboard, orders, menu, reservations, tables,
// floor, POS, table analytics). Imported from app.js; ES imports are evaluated before
// app.js's body, so these globals exist before Alpine.start() evaluates x-data.
import { createIcons, icons } from 'lucide';
import QRCode from 'qrcode';
window.QRCode = QRCode;

// Pre-render lucide icons inside <template> content too, so rows cloned later by
// Alpine x-for / x-if already contain <svg> icons (no renderIcons() call needed).
window.renderIconsDeep = () => createIcons({ icons, attrs: { 'stroke-width': 2 }, inTemplates: true });
// Module scripts run after parsing, so render now — before Alpine.start() clones templates.
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => window.renderIconsDeep());
else window.renderIconsDeep();

/**
 * Minimal date-fns `format()` for the patterns the Next admin uses
 * (EEE, MMM, d, yyyy, h, mm, a), in the browser's local time.
 * e.g. fmtDate(iso, 'MMM d, h:mm a') → "Jun 25, 7:05 PM". Quote literals with '…'.
 */
window.fmtDate = (value, pattern = 'MMM d, yyyy') => {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const h12 = d.getHours() % 12 || 12;
  const map = {
    yyyy: String(d.getFullYear()),
    EEE: DAYS[d.getDay()],
    MMM: MONTHS[d.getMonth()],
    MM: String(d.getMonth() + 1).padStart(2, '0'),
    dd: String(d.getDate()).padStart(2, '0'),
    d: String(d.getDate()),
    hh: String(h12).padStart(2, '0'),
    h: String(h12),
    HH: String(d.getHours()).padStart(2, '0'),
    mm: String(d.getMinutes()).padStart(2, '0'),
    a: d.getHours() < 12 ? 'AM' : 'PM',
  };
  return pattern.replace(/'([^']*)'|yyyy|EEE|MMM|MM|dd|d|hh|h|HH|mm|a/g, (m, lit) => (lit !== undefined ? lit : map[m]));
};

/** Trigger a client-side file download (CSV / .xls exports). */
window.downloadFile = (name, type, content) => {
  const blob = content instanceof Blob ? content : new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
};

/** Rows → CSV text with every cell quoted (same as the Next exports). */
window.toCsv = (rows) =>
  rows.map((r) => r.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');

/** formatCurrency() from the Next admin: "$15,750" (0 decimals by default). */
window.formatCurrency = (v, opts = {}) =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0, ...opts }).format(Number(v || 0));
