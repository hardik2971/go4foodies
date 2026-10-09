// Storefront payment helper — supports two gateways (Razorpay + Stripe). The
// customer picks one (when both are configured); each gateway is created via the
// admin (proxied at /api/payment) and confirmed in the browser. The verified
// result is sent with the order/gift-card request and re-checked server-side.
//
// Returns `null` only when NO gateway is configured (dev fallback → the caller
// submits without a payment). A cancelled/failed payment throws.

export type PaymentResult =
  | { provider: 'razorpay'; orderId: string; paymentId: string; signature: string }
  | { provider: 'stripe'; paymentIntentId: string }
  | { provider: 'paypal'; orderId: string };

type Provider = 'razorpay' | 'stripe' | 'paypal';

export interface PayOptions {
  amount: number;
  description: string;
  name: string;
  email?: string;
  phone?: string;
}

declare global {
  interface Window {
    Razorpay?: new (options: Record<string, unknown>) => { open: () => void; on: (e: string, cb: (r: unknown) => void) => void };
    Stripe?: (key: string) => StripeLike;
    paypal?: PayPalLike;
  }
}

interface StripeLike {
  elements: (opts: Record<string, unknown>) => { create: (t: string) => { mount: (el: HTMLElement) => void } };
  confirmPayment: (opts: Record<string, unknown>) => Promise<{ error?: { message?: string }; paymentIntent?: { id: string; status: string } }>;
}

interface PayPalLike {
  Buttons: (opts: Record<string, unknown>) => { render: (el: HTMLElement) => Promise<void> };
}

// Brand logomarks (single-path, simple-icons) tinted with each brand colour.
const BRAND_SVG: Record<Provider, string> = {
  razorpay:
    '<svg viewBox="0 0 24 24" fill="#3395FF"><path d="M22.436 0l-11.91 7.773-1.174 4.276 6.625-4.297L11.65 24h4.391l6.395-24zM14.26 10.098L3.389 17.166 1.564 24h9.008l3.688-13.902z"/></svg>',
  stripe:
    '<svg viewBox="0 0 24 24" fill="#635BFF"><path d="M13.976 9.15c-2.172-.806-3.356-1.426-3.356-2.409 0-.831.683-1.305 1.901-1.305 2.227 0 4.515.858 6.09 1.631l.89-5.494C18.252.975 15.697 0 12.165 0 9.667 0 7.589.654 6.104 1.872 4.56 3.147 3.757 4.992 3.757 7.218c0 4.039 2.467 5.76 6.476 7.219 2.585.92 3.445 1.574 3.445 2.583 0 .98-.84 1.545-2.354 1.545-1.875 0-4.965-.921-6.99-2.109l-.9 5.555C5.175 22.99 8.385 24 11.714 24c2.641 0 4.843-.624 6.328-1.813 1.664-1.305 2.525-3.236 2.525-5.732 0-4.128-2.524-5.851-6.594-7.305z"/></svg>',
  paypal:
    '<svg viewBox="0 0 24 24" fill="#0070E0"><path d="M7.076 21.337H2.47a.641.641 0 0 1-.633-.74L4.944.901C5.026.382 5.474 0 5.998 0h7.46c2.57 0 4.578.543 5.69 1.81 1.01 1.15 1.304 2.42 1.012 4.287-.023.143-.047.288-.077.437-.983 5.05-4.349 6.797-8.647 6.797h-2.19c-.524 0-.968.382-1.05.9l-1.12 7.106zm14.146-14.42a3.35 3.35 0 0 0-.607-.541c-.013.076-.026.175-.041.254-.93 4.778-4.005 7.201-9.138 7.201h-2.19a.563.563 0 0 0-.556.479l-1.187 7.527h-.506l-.24 1.516a.56.56 0 0 0 .554.647h3.882c.46 0 .85-.334.922-.788.06-.26.76-4.852.816-5.09a.932.932 0 0 1 .923-.788h.58c3.76 0 6.705-1.528 7.565-5.946.36-1.847.174-3.388-.777-4.471z"/></svg>',
};

const PROVIDER_META: Record<Provider, { label: string; sub: string }> = {
  razorpay: { label: 'Razorpay', sub: 'Cards, UPI, netbanking & wallets' },
  stripe: { label: 'Stripe', sub: 'Pay securely by debit / credit card' },
  paypal: { label: 'PayPal', sub: 'Pay with your PayPal balance or card' },
};

const CHEVRON_SVG =
  '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>';
const LOCK_SVG =
  '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>';

// Scoped modal styles (injected once) — enables :hover / transitions / animation
// that inline styles can't express.
let stylesInjected = false;
function injectStyles() {
  if (stylesInjected || typeof document === 'undefined') return;
  stylesInjected = true;
  const style = document.createElement('style');
  style.textContent = `
    .pay-overlay{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;background:rgba(5,14,12,.8);backdrop-filter:blur(6px);padding:16px;animation:pay-fade .22s ease;font-family:inherit;}
    .pay-card{width:100%;max-width:440px;background:linear-gradient(180deg,#12302a,#0a1c18);border:1px solid rgba(245, 118, 30,.28);border-radius:20px;padding:26px;color:#f5efe6;box-shadow:0 30px 80px rgba(0,0,0,.6);animation:pay-rise .28s cubic-bezier(.2,.8,.2,1);}
    .pay-head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;}
    .pay-title{font-size:19px;font-weight:600;margin:0;letter-spacing:.2px;}
    .pay-cap{font-size:12.5px;color:#8ea39b;margin:3px 0 20px;}
    .pay-close{flex:none;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.09);color:#bccbc5;width:32px;height:32px;border-radius:50%;font-size:17px;line-height:1;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:.15s;}
    .pay-close:hover{background:rgba(255,255,255,.12);color:#fff;}
    .pay-opt{display:flex;align-items:center;gap:14px;width:100%;text-align:left;margin-bottom:12px;padding:14px 16px;border:1px solid rgba(255,255,255,.09);border-radius:14px;background:rgba(255,255,255,.025);color:#f5efe6;cursor:pointer;transition:border-color .18s,background .18s,transform .18s;}
    .pay-opt:last-of-type{margin-bottom:0;}
    .pay-opt:hover{border-color:rgba(245, 118, 30,.6);background:rgba(245, 118, 30,.07);transform:translateY(-1px);}
    .pay-ico{flex:none;width:46px;height:46px;border-radius:12px;background:#fff;display:flex;align-items:center;justify-content:center;box-shadow:inset 0 0 0 1px rgba(0,0,0,.06);}
    .pay-ico svg{width:26px;height:26px;}
    .pay-txt{flex:1;min-width:0;}
    .pay-label{display:block;font-weight:600;font-size:15px;}
    .pay-osub{display:block;font-size:12px;color:#90a59d;margin-top:1px;}
    .pay-chev{flex:none;color:#7b9088;transition:color .18s,transform .18s;}
    .pay-opt:hover .pay-chev{color:#f5761e;transform:translateX(3px);}
    .pay-secure{display:flex;align-items:center;justify-content:center;gap:6px;margin-top:18px;font-size:11.5px;color:#7b9088;letter-spacing:.2px;}
    .pay-mount{margin-top:4px;}
    .pay-err{color:#f87171;font-size:13px;margin:12px 0 0;min-height:16px;}
    .pay-btn{width:100%;margin-top:18px;padding:12px 16px;border:none;border-radius:11px;background:${GOLD};color:#fff;font-weight:700;font-size:15px;cursor:pointer;transition:filter .15s;}
    .pay-btn:hover{filter:brightness(1.06);}
    .pay-btn:disabled{opacity:.7;cursor:default;}
    @keyframes pay-fade{from{opacity:0}to{opacity:1}}
    @keyframes pay-rise{from{opacity:0;transform:translateY(12px) scale(.98)}to{opacity:1;transform:none}}
  `;
  document.head.appendChild(style);
}

const GOLD = '#f5761e';

function loadScript(src: string, test: () => boolean): Promise<boolean> {
  if (typeof window === 'undefined') return Promise.resolve(false);
  if (test()) return Promise.resolve(true);
  return new Promise((resolve) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = () => resolve(true);
    s.onerror = () => resolve(false);
    document.body.appendChild(s);
  });
}

async function getProviders(): Promise<{ razorpay: boolean; stripe: boolean; paypal: boolean }> {
  try {
    const res = await fetch('/api/payment', { cache: 'no-store' });
    if (!res.ok) return { razorpay: false, stripe: false, paypal: false };
    return await res.json();
  } catch {
    return { razorpay: false, stripe: false, paypal: false };
  }
}

// ---- shared imperative modal (matches the storefront's dark / gold theme) ----
function buildModal(title: string, caption?: string) {
  injectStyles();
  const overlay = document.createElement('div');
  overlay.className = 'pay-overlay';
  const card = document.createElement('div');
  card.className = 'pay-card';
  const header = document.createElement('div');
  header.className = 'pay-head';
  const titleWrap = document.createElement('div');
  const h = document.createElement('h3');
  h.className = 'pay-title';
  h.textContent = title;
  titleWrap.append(h);
  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'pay-close';
  close.innerHTML = '&times;';
  close.setAttribute('aria-label', 'Close');
  header.append(titleWrap, close);
  const body = document.createElement('div');
  card.append(header);
  if (caption) {
    const cap = document.createElement('p');
    cap.className = 'pay-cap';
    cap.textContent = caption;
    card.append(cap);
  }
  card.append(body);
  overlay.append(card);
  document.body.append(overlay);
  return { overlay, body, close, cleanup: () => overlay.remove() };
}

function goldButton(label: string): HTMLButtonElement {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = 'pay-btn';
  b.textContent = label;
  return b;
}

function secureFooter(): HTMLElement {
  const el = document.createElement('div');
  el.className = 'pay-secure';
  el.innerHTML = `${LOCK_SVG}<span>Secured &amp; encrypted payment</span>`;
  return el;
}

// ---- provider chooser (shown when more than one gateway is live) ----
function chooseProvider(available: Provider[]): Promise<Provider | null> {
  return new Promise((resolve) => {
    const { overlay, body, close, cleanup } = buildModal('Choose payment method', 'Select how you’d like to pay securely.');
    const done = (v: Provider | null) => {
      cleanup();
      resolve(v);
    };
    for (const val of available) {
      const { label, sub } = PROVIDER_META[val];
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'pay-opt';
      btn.innerHTML =
        `<span class="pay-ico">${BRAND_SVG[val]}</span>` +
        `<span class="pay-txt"><span class="pay-label">${label}</span><span class="pay-osub">${sub}</span></span>` +
        `<span class="pay-chev">${CHEVRON_SVG}</span>`;
      btn.onclick = () => done(val);
      body.append(btn);
    }
    body.append(secureFooter());
    close.onclick = () => done(null);
    overlay.onclick = (e) => {
      if (e.target === overlay) done(null);
    };
  });
}

// ---- Razorpay ----
async function payRazorpay(opts: PayOptions): Promise<PaymentResult> {
  const res = await fetch('/api/payment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider: 'razorpay', amount: opts.amount, description: opts.description }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Could not start payment.');

  const loaded = await loadScript('https://checkout.razorpay.com/v1/checkout.js', () => !!window.Razorpay);
  if (!loaded || !window.Razorpay) throw new Error('Could not load Razorpay.');

  return new Promise<PaymentResult>((resolve, reject) => {
    const rzp = new window.Razorpay!({
      key: data.keyId,
      order_id: data.orderId,
      amount: data.amount,
      currency: data.currency,
      name: 'Go4Foodie',
      description: opts.description,
      prefill: { name: opts.name, email: opts.email, contact: opts.phone },
      theme: { color: GOLD },
      handler: (r: unknown) => {
        const c = r as { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string };
        resolve({ provider: 'razorpay', orderId: c.razorpay_order_id, paymentId: c.razorpay_payment_id, signature: c.razorpay_signature });
      },
      modal: { ondismiss: () => reject(new Error('Payment cancelled.')) },
    });
    rzp.on('payment.failed', (resp: unknown) => {
      const e = resp as { error?: { description?: string } };
      reject(new Error(e?.error?.description || 'Payment failed.'));
    });
    rzp.open();
  });
}

// ---- Stripe (Payment Element, confirmed inline — no redirect) ----
async function payStripe(opts: PayOptions): Promise<PaymentResult> {
  const res = await fetch('/api/payment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider: 'stripe', amount: opts.amount, description: opts.description }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Could not start payment.');

  const loaded = await loadScript('https://js.stripe.com/v3/', () => !!window.Stripe);
  if (!loaded || !window.Stripe) throw new Error('Could not load Stripe.');
  const stripe = window.Stripe(data.publishableKey);

  return new Promise<PaymentResult>((resolve, reject) => {
    const { overlay, body, close, cleanup } = buildModal('Pay by card', `Amount due · $${opts.amount.toFixed(2)}`);
    const mountEl = document.createElement('div');
    mountEl.className = 'pay-mount';
    body.append(mountEl);
    const errEl = document.createElement('p');
    errEl.className = 'pay-err';
    const payBtn = goldButton(`Pay $${opts.amount.toFixed(2)}`);
    body.append(errEl, payBtn, secureFooter());

    const elements = stripe.elements({ clientSecret: data.clientSecret, appearance: { theme: 'night', variables: { colorPrimary: GOLD } } });
    elements.create('payment').mount(mountEl);

    let settled = false;
    const cancel = () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error('Payment cancelled.'));
    };
    close.onclick = cancel;
    overlay.onclick = (e) => {
      if (e.target === overlay) cancel();
    };
    payBtn.onclick = async () => {
      payBtn.disabled = true;
      payBtn.textContent = 'Processing…';
      errEl.textContent = '';
      const { error, paymentIntent } = await stripe.confirmPayment({ elements, redirect: 'if_required' });
      if (error) {
        errEl.textContent = error.message || 'Payment failed.';
        payBtn.disabled = false;
        payBtn.textContent = `Pay $${opts.amount.toFixed(2)}`;
        return;
      }
      if (paymentIntent && paymentIntent.status === 'succeeded') {
        settled = true;
        cleanup();
        resolve({ provider: 'stripe', paymentIntentId: paymentIntent.id });
        return;
      }
      errEl.textContent = 'Payment not completed.';
      payBtn.disabled = false;
      payBtn.textContent = `Pay $${opts.amount.toFixed(2)}`;
    };
  });
}

// ---- PayPal (Buttons, approve + server capture — no redirect) ----
async function payPayPal(opts: PayOptions): Promise<PaymentResult> {
  const res = await fetch('/api/payment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider: 'paypal', amount: opts.amount, description: opts.description }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Could not start payment.');

  const sdk = `https://www.paypal.com/sdk/js?client-id=${encodeURIComponent(data.clientId)}&currency=${encodeURIComponent(data.currency || 'USD')}`;
  const loaded = await loadScript(sdk, () => !!window.paypal);
  if (!loaded || !window.paypal) throw new Error('Could not load PayPal.');

  return new Promise<PaymentResult>((resolve, reject) => {
    const { overlay, body, close, cleanup } = buildModal('Pay with PayPal', `Amount due · $${opts.amount.toFixed(2)}`);
    const btnHost = document.createElement('div');
    btnHost.className = 'pay-mount';
    const errEl = document.createElement('p');
    errEl.className = 'pay-err';
    body.append(btnHost, errEl, secureFooter());

    let settled = false;
    const cancel = () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error('Payment cancelled.'));
    };
    close.onclick = cancel;
    overlay.onclick = (e) => {
      if (e.target === overlay) cancel();
    };

    window
      .paypal!.Buttons({
        createOrder: () => data.orderId,
        onApprove: async () => {
          try {
            const cap = await fetch('/api/payment/capture', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ orderId: data.orderId }),
            });
            const capData = await cap.json();
            if (!cap.ok || capData.status !== 'COMPLETED') {
              throw new Error(capData.error || 'Payment not completed.');
            }
            settled = true;
            cleanup();
            resolve({ provider: 'paypal', orderId: data.orderId });
          } catch (err) {
            errEl.textContent = err instanceof Error ? err.message : 'Payment failed.';
          }
        },
        onError: () => {
          errEl.textContent = 'Payment failed. Please try again.';
        },
      })
      .render(btnHost)
      .catch(() => {
        errEl.textContent = 'Could not display PayPal.';
      });
  });
}

/** Run checkout. Returns the verified payment, or null if no gateway is configured. */
export async function pay(opts: PayOptions): Promise<PaymentResult | null> {
  const providers = await getProviders();
  const available = (['razorpay', 'stripe', 'paypal'] as Provider[]).filter((p) => providers[p]);
  if (available.length === 0) return null; // dev fallback

  let provider: Provider;
  if (available.length > 1) {
    const chosen = await chooseProvider(available);
    if (!chosen) throw new Error('Payment cancelled.');
    provider = chosen;
  } else {
    provider = available[0];
  }

  if (provider === 'stripe') return payStripe(opts);
  if (provider === 'paypal') return payPayPal(opts);
  return payRazorpay(opts);
}
