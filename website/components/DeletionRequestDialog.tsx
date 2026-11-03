'use client';

import { useEffect, useState, type FormEvent } from 'react';

const fieldClass =
  'w-full rounded-xl border border-cream/15 bg-ink-soft px-4 py-3 text-sm text-cream outline-none transition-colors placeholder:text-cream/35 focus:border-gold';
const labelClass = 'mb-2 block text-xs font-semibold uppercase tracking-[0.18em] text-cream/60';

const EMPTY = { name: '', email: '', phone: '', reason: '', confirm: false, website: '' };

/** "Email a deletion request" → form dialog → POST /api/account-deletion → success popup (auto-closes after 3s). */
export default function DeletionRequestDialog({ className = 'btn-primary mt-6' }: { className?: string }) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState<string | null>(null); // reference of the submitted request

  const set = <K extends keyof typeof EMPTY>(k: K, v: (typeof EMPTY)[K]) => {
    setForm((f) => ({ ...f, [k]: v }));
    setError('');
  };
  const close = () => {
    setOpen(false);
    setError('');
  };

  // Escape closes the form dialog.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && close();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open]);

  // The success popup removes itself after 3 seconds.
  useEffect(() => {
    if (done === null) return;
    const t = setTimeout(() => setDone(null), 3000);
    return () => clearTimeout(t);
  }, [done]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!form.confirm) return setError('Please confirm you want your account deleted.');
    setBusy(true);
    setError('');
    try {
      const res = await fetch('/api/account-deletion', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      const data = (await res.json().catch(() => ({}))) as { reference?: string; error?: string };
      if (!res.ok) throw new Error(data.error || 'Could not send your request. Please try again.');
      setOpen(false);
      setForm(EMPTY);
      setDone(data.reference ?? '');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send your request. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button type="button" onClick={() => setOpen(true)} className={className}>
        Email a deletion request
      </button>

      {open && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-ink/70 backdrop-blur-sm" onClick={close} aria-hidden="true" />
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="del-title"
            className="relative z-10 max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-[1.5rem] bg-ink p-6 shadow-float ring-1 ring-cream/10 sm:p-8"
          >
            <div className="pointer-events-none absolute -right-24 top-0 h-60 w-60 rounded-full bg-gold/15 blur-[110px]" />
            <button
              type="button"
              onClick={close}
              aria-label="Close"
              className="absolute right-4 top-4 z-10 grid h-9 w-9 place-items-center rounded-full border border-cream/20 text-cream transition-colors hover:border-gold hover:text-gold"
            >
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </button>

            <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold">Go4Foodie</p>
            <h2 id="del-title" className="mt-2 font-display text-2xl font-bold uppercase tracking-tight text-cream">
              Delete my account
            </h2>
            <p className="mt-2 text-sm leading-relaxed text-cream/60">
              Use the e-mail address you sign in with. We delete your account and personal data within 30 days and
              e-mail you when it is done.
            </p>

            <form onSubmit={submit} className="relative mt-6 space-y-4" noValidate>
              <div>
                <label htmlFor="del-name" className={labelClass}>Name on the account *</label>
                <input id="del-name" required autoComplete="name" value={form.name} onChange={(e) => set('name', e.target.value)} placeholder="Jane Doe" className={fieldClass} />
              </div>
              <div>
                <label htmlFor="del-email" className={labelClass}>Account e-mail *</label>
                <input id="del-email" type="email" required autoComplete="email" value={form.email} onChange={(e) => set('email', e.target.value)} placeholder="you@example.com" className={fieldClass} />
              </div>
              <div>
                <label htmlFor="del-phone" className={labelClass}>Phone (optional)</label>
                <input id="del-phone" type="tel" autoComplete="tel" value={form.phone} onChange={(e) => set('phone', e.target.value)} placeholder="+91 98765 43210" className={fieldClass} />
              </div>
              <div>
                <label htmlFor="del-reason" className={labelClass}>Reason (optional)</label>
                <textarea id="del-reason" rows={3} value={form.reason} onChange={(e) => set('reason', e.target.value)} placeholder="Tell us why you are leaving" className={`${fieldClass} resize-none`} />
              </div>
              {/* Honeypot — hidden from people, filled by bots. */}
              <input tabIndex={-1} autoComplete="off" aria-hidden="true" value={form.website} onChange={(e) => set('website', e.target.value)} className="absolute -left-[9999px] h-0 w-0 opacity-0" />

              <label className="flex cursor-pointer items-start gap-3 text-sm leading-relaxed text-cream/70">
                <input type="checkbox" checked={form.confirm} onChange={(e) => set('confirm', e.target.checked)} className="mt-1 h-4 w-4 shrink-0 accent-[#f5761e]" />
                I understand my Go4Foodie account and personal data will be permanently deleted. This cannot be undone.
              </label>

              {error && <p role="alert" className="rounded-xl border border-red-400/40 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</p>}

              <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
                <button type="button" onClick={close} className="btn-ghost">Cancel</button>
                <button type="submit" disabled={busy} className="btn-primary disabled:cursor-not-allowed disabled:opacity-60">
                  {busy ? 'Sending…' : 'Submit request'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {done !== null && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center p-4" onClick={() => setDone(null)}>
          <div className="absolute inset-0 bg-ink/60 backdrop-blur-sm" aria-hidden="true" />
          <div role="status" aria-live="polite" className="relative z-10 w-full max-w-sm overflow-hidden rounded-[1.5rem] bg-ink p-8 text-center shadow-float ring-1 ring-gold/40">
            <div className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-gold text-ink">
              <svg viewBox="0 0 24 24" className="h-7 w-7" aria-hidden="true">
                <path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
            <h3 className="mt-5 font-display text-xl font-bold uppercase tracking-tight text-cream">Request received</h3>
            <p className="mt-2 text-sm leading-relaxed text-cream/70">
              We&apos;ve e-mailed you a confirmation{done ? <> (reference <span className="font-semibold text-gold">{done}</span>)</> : null}. Your
              account will be deleted within 30 days.
            </p>
            {/* 3-second countdown bar */}
            <div className="absolute inset-x-0 bottom-0 h-1 bg-cream/10">
              <div className="h-full origin-left bg-gold" style={{ animation: 'del-countdown 3s linear forwards' }} />
            </div>
            <style>{'@keyframes del-countdown{from{transform:scaleX(1)}to{transform:scaleX(0)}}'}</style>
          </div>
        </div>
      )}
    </>
  );
}
