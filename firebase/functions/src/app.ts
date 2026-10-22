import express from 'express';
import { errorHandler, adminSession } from './lib/http';
import publicRoutes from './routes/public';
import mobileRoutes from './routes/mobile';
import adminRoutes from './routes/admin';

/**
 * One Express app serves the whole REST API, with the same paths and JSON as the old
 * Laravel backend (so the website and mobile app only switch base URL):
 *   /api/*          public website API          (routes/public.ts)
 *   /api/mobile/*   Flutter app API (HS256 JWT) (routes/mobile.ts)
 *   /api/admin/*    Flutter Web admin API       (routes/admin.ts, Firebase ID token)
 * Firebase Hosting rewrites /api/** to this function.
 */
export const app = express();
app.disable('x-powered-by');
app.use((req, res, next) => {
  // The website calls server-side; the admin + mobile apps call cross-origin.
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});
app.use(express.json({ limit: '1mb' }));
// Unparseable JSON → body null (Body::json), so it fails schema validation like the PHP did.
app.use((err: { type?: string }, req: express.Request, _res: express.Response, next: express.NextFunction) => {
  if (err?.type !== 'entity.parse.failed') return next(err);
  req.body = null;
  next();
});
app.use(adminSession);

app.use('/api/mobile', mobileRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', publicRoutes);
app.get('/up', (_req, res) => { res.send('ok'); });
app.use((_req, res) => { res.status(404).json({ error: 'Not found' }); });
app.use(errorHandler);
