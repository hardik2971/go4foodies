// Server-only base URL for the backend API (the Firebase `api` function behind Hosting).
// The storefront's own route handlers proxy to it so the browser only ever calls
// same-origin /api/*. Override with ADMIN_API_URL (e.g. http://127.0.0.1:8787 for a local run).
export const ADMIN_API_URL = (process.env.ADMIN_API_URL ?? 'https://go4foodies.web.app').replace(/\/$/, '');
