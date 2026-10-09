// Server-only base URL for the admin app's API. The storefront's own route
// handlers proxy to it so the browser only ever calls same-origin /api/*
// (no CORS, admin host stays private). Set ADMIN_API_URL in the environment;
// defaults to the local admin dev/start port (33664).
export const ADMIN_API_URL = (process.env.ADMIN_API_URL ?? 'http://127.0.0.1:33664').replace(/\/$/, '');
