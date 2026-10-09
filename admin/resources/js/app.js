import Alpine from 'alpinejs';
import Chart from 'chart.js/auto';
import { createIcons, icons } from 'lucide';

window.Chart = Chart;
window.Alpine = Alpine;

/** Render <i data-lucide="name"> placeholders (also after Alpine updates the DOM). */
window.renderIcons = () => createIcons({ icons, attrs: { 'stroke-width': 2 } });

/**
 * JSON fetch helper for interactive pages (POS, floor, modals).
 * Sends the CSRF token; throws Error(message) using the server's {error}.
 */
window.api = async (url, { method = 'GET', body } = {}) => {
  const res = await fetch(url, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content ?? '',
      'X-Requested-With': 'XMLHttpRequest',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const first = data.errors ? Object.values(data.errors)[0]?.[0] : null;
    throw new Error(data.error || first || data.message || `Request failed (${res.status})`);
  }
  return data;
};

/** Toasts: window.toast('Saved') / window.toast('Oops', 'error'). */
window.toast = (message, type = 'success') =>
  window.dispatchEvent(new CustomEvent('toast', { detail: { message, type } }));

/** Theme (persisted like the Next.js admin: localStorage 'admin-theme'). */
window.toggleTheme = () => {
  const dark = !document.documentElement.classList.contains('dark');
  document.documentElement.classList.toggle('dark', dark);
  try {
    localStorage.setItem('admin-theme', dark ? 'dark' : 'light');
  } catch {
    /* ignore */
  }
  window.dispatchEvent(new CustomEvent('theme-changed', { detail: { dark } }));
};

/** Theme-aware chart colours (read from CSS variables). */
window.themeColor = (name) =>
  getComputedStyle(document.documentElement).getPropertyValue(`--color-${name}`).trim();

/** Currency/date formatting shared by Alpine components. */
window.money = (v, currency = 'USD') =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(Number(v || 0));

document.addEventListener('DOMContentLoaded', () => window.renderIcons());
document.addEventListener('alpine:initialized', () => window.renderIcons());

Alpine.start();

// ---- Operations pages helpers (QRCode, fmtDate, formatCurrency, downloadFile, toCsv, renderIconsDeep) ----
import './ops.js';
