import { C, db, now, ref } from '../lib/db';
import { cuid } from '../lib/cuid';
import { setCredentials } from './actions';

/**
 * `Customer::where('email', $email)->first()` then update or `Customer::create(...)` — the
 * "link/create a customer by email" step of online orders, reservations and gift cards.
 * MySQL matched email case-insensitively (utf8mb4_unicode_ci), hence `emailLower`.
 * `phone` undefined leaves an existing customer's phone untouched. Returns the customer id.
 */
export async function upsertCustomerByEmail(email: string, data: { name: string; phone?: string | null }): Promise<string> {
  const created = await db.runTransaction(async (tx) => {
    const q = await tx.get(db.collection(C.customers).where('emailLower', '==', email.toLowerCase()).limit(1));
    const t = now();
    if (!q.empty) {
      tx.update(q.docs[0].ref, { name: data.name, ...(data.phone !== undefined ? { phone: data.phone } : {}), updatedAt: t });
      return { id: q.docs[0].id, isNew: false };
    }
    const id = cuid();
    tx.create(ref(C.customers, id), {
      name: data.name,
      email,
      emailLower: email.toLowerCase(),
      phone: data.phone ?? null,
      address: null,
      status: 'ACTIVE',
      createdAt: t,
      updatedAt: t,
    });
    return { id, isNew: true };
  });
  if (created.isNew) await setCredentials('customer', created.id, { email });
  return created.id;
}
