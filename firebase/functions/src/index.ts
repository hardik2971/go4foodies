import { onRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { app } from './app';

setGlobalOptions({ region: 'asia-south1' });

export const api = onRequest(
  {
    memory: '512MiB',
    timeoutSeconds: 120,
    minInstances: 0,
    // Runs as the Firebase Admin SDK service account: it holds Service Account Token Creator,
    // which admin login needs to mint Firebase custom tokens (signBlob).
    serviceAccount: 'firebase-adminsdk-fbsvc@go4foodies.iam.gserviceaccount.com',
    secrets: ['AUTH_SECRET', 'MAIL_PASSWORD', 'RAZORPAY_KEY_SECRET', 'STRIPE_SECRET_KEY', 'PAYPAL_CLIENT_SECRET'],
  },
  app,
);
