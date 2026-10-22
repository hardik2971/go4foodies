// Local runner against the real Firestore (no emulator): `npm run dev`.
// Uses GOOGLE_APPLICATION_CREDENTIALS + env from ../.env.local (never deployed).
import { app } from './app';

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => console.log(`api listening on http://localhost:${port}`));
