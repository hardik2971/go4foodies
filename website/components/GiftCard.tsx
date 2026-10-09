"use client";

import { useState, useEffect } from "react";
import Reveal from "./Reveal";
import Image from "next/image";
import { pay } from "@/lib/payment";

const AMOUNTS = [10, 50, 100, 200, 250, 500, 750, 1000];
const QUANTITIES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const TIMINGS = ["Send instantly", "Send on a future date"];
const STEPS = ["Amount", "Details", "Delivery", "Review"] as const;

const BENEFITS = [
  "Delivered instantly by email",
  "Never expires - spend any time",
  "Redeemable on dining, wine & private events",
];

interface GiftForm {
  kind: "GIFT_CARD" | "COUPON";
  amount: number;
  recipientType: "someone" | "self";
  quantity: number;
  yourName: string;
  recipientName: string;
  message: string;
  delivery: "email" | "print";
  email: string;
  timing: string;
  sendDate: string;
}

const initialForm: GiftForm = {
  kind: "GIFT_CARD",
  amount: 100,
  recipientType: "someone",
  quantity: 1,
  yourName: "",
  recipientName: "",
  message: "",
  delivery: "email",
  email: "",
  timing: TIMINGS[0],
  sendDate: "",
};

const fieldClass =
  "w-full rounded-xl border border-cream/15 bg-ink-soft px-4 py-3 text-sm text-cream outline-none transition-colors placeholder:text-cream/35 focus:border-gold";

type CSSVars = React.CSSProperties & Record<`--${string}`, string | number>;

const CONFETTI_COLORS = ["#f5761e", "#ffb067", "#e0541a", "#f7f1e8", "#e2470f"];

// Deterministic firecracker burst (avoids SSR/random mismatches).
const CONFETTI = Array.from({ length: 56 }, (_, i) => {
  const angle = (i / 56) * Math.PI * 2;
  const radius = 130 + (i % 6) * 34;
  return {
    dx: Math.cos(angle) * radius,
    dy: Math.sin(angle) * radius + 220, // gravity: pieces drift downward
    rot: (i % 2 ? 1 : -1) * (360 + (i % 4) * 200),
    color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
    delay: (i % 7) * 55,
    w: 6 + (i % 3) * 3,
    h: 9 + (i % 4) * 3,
  };
});

function Confetti() {
  return (
    <div
      className="pointer-events-none absolute inset-0 overflow-hidden"
      aria-hidden="true"
    >
      {CONFETTI.map((c, i) => (
        <span
          key={i}
          className="absolute left-1/2 top-[28%] animate-confetti rounded-[1px]"
          style={
            {
              "--dx": `${c.dx}px`,
              "--dy": `${c.dy}px`,
              "--rot": `${c.rot}deg`,
              width: `${c.w}px`,
              height: `${c.h}px`,
              background: c.color,
              animationDelay: `${c.delay}ms`,
            } as CSSVars
          }
        />
      ))}
    </div>
  );
}

const labelClass =
  "mb-2 block text-xs font-semibold uppercase tracking-[0.18em] text-cream/60";

function Stepper({ step }: { step: number }) {
  return (
    <div className="flex items-center justify-center gap-2.5">
      {STEPS.map((label, i) => (
        <span
          key={label}
          className={`h-2.5 rounded-full transition-all duration-300 ${
            i === step
              ? "w-7 bg-gold"
              : i < step
                ? "w-2.5 bg-gold/60"
                : "w-2.5 bg-cream/20"
          }`}
        />
      ))}
    </div>
  );
}

interface ToggleOption<T> {
  value: T;
  label: string;
  icon: React.ReactNode;
}

function Toggle<T extends string>({
  options,
  value,
  onChange,
}: {
  options: ToggleOption<T>[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="grid grid-cols-2 gap-1.5 rounded-xl border border-cream/15 bg-ink-soft p-1.5">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          onClick={() => onChange(o.value)}
          aria-pressed={value === o.value}
          className={`flex items-center justify-center gap-2 rounded-lg px-3 py-2.5 text-sm font-semibold transition-colors ${
            value === o.value
              ? "bg-gold text-white"
              : "text-cream/70 hover:text-cream"
          }`}
        >
          {o.icon}
          {o.label}
        </button>
      ))}
    </div>
  );
}

export default function GiftCard() {
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState(0);
  const [form, setForm] = useState<GiftForm>(initialForm);
  const [reference, setReference] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const set = <K extends keyof GiftForm>(key: K, value: GiftForm[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  // Allow other components (e.g. the hero CTA) to open this dialog.
  useEffect(() => {
    const openHandler = () => {
      setStep(0);
      setOpen(true);
    };
    window.addEventListener("open-giftcard", openHandler);
    return () => window.removeEventListener("open-giftcard", openHandler);
  }, []);

  // Close on Escape + lock body scroll while the dialog is open.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open]);

  const total = form.amount * form.quantity;

  const stepValid =
    step === 0
      ? form.amount > 0
      : step === 1
        ? form.yourName.trim() !== "" &&
          (form.recipientType === "self" || form.recipientName.trim() !== "")
        : step === 2
          ? form.delivery === "print" ||
            (form.email.trim() !== "" &&
              (form.timing !== "Send on a future date" || form.sendDate !== ""))
          : true;

  // Razorpay payment → generate a real coupon code via the admin API.
  const purchase = async () => {
    setSubmitting(true);
    setError("");
    try {
      const payment = await pay({
        amount: form.amount,
        description: `${form.kind === "COUPON" ? "Coupon" : "Gift card"} · $${form.amount}`,
        name: form.yourName,
        email: form.email || undefined,
      });
      const res = await fetch("/api/gift-cards", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          kind: form.kind,
          amount: form.amount,
          name: form.yourName,
          email: form.email || undefined,
          message: form.message || undefined,
          payment: payment ?? undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not complete your purchase.");
      setReference(data.code);
      setStep(4);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  const reset = () => {
    setForm(initialForm);
    setReference("");
    setError("");
    setStep(0);
  };

  return (
    <>
      {/* ---- Section: premium gift-card showcase ---- */}
      <section id="gift-cards" className="section bg-[#fbeee0]">
        <div className="container">
          <div className="relative overflow-hidden sm:rounded-[2.5rem] rounded-2xl bg-ink px-6 py-14 shadow-[0_40px_90px_-40px_rgba(10,28,24,0.7)] sm:px-10 lg:px-16 lg:py-20">
            {/* ambient gold glows + inner ring */}
            <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-gold/15 blur-[120px]" />
            <div className="pointer-events-none absolute -bottom-24 -left-24 h-80 w-80 rounded-full bg-gold/10 blur-[120px]" />
            <div className="pointer-events-none absolute inset-3 sm:rounded-[2rem] rounded-2xl ring-1 ring-gold/15" />

            <div className="relative grid items-center gap-12 lg:grid-cols-2">
              {/* Copy */}
              <div className="order-2 lg:order-1">
                <Reveal>
                  <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold">
                    The Gift of Great Taste
                  </p>
                </Reveal>
                <Reveal delay={1}>
                  <h2 className="mt-4 font-display text-[clamp(2.4rem,5vw,4rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                    Gift Cards
                  </h2>
                </Reveal>
                <Reveal delay={2}>
                  <p className="mt-5 max-w-md text-sm leading-relaxed text-cream/65">
                    Give an unforgettable evening of wood-fired plates, curated
                    wine, and private events - delivered instantly, beautifully,
                    and never expiring.
                  </p>
                </Reveal>
                <Reveal delay={2}>
                  <ul className="mt-7 flex flex-wrap gap-x-6 gap-y-2.5">
                    {BENEFITS.map((b) => (
                      <li
                        key={b}
                        className="flex items-center gap-2 text-xs text-cream/70"
                      >
                        <span className="h-1.5 w-1.5 rounded-full bg-gold" />
                        {b}
                      </li>
                    ))}
                  </ul>
                </Reveal>
                <Reveal delay={3}>
                  <button
                    type="button"
                    onClick={() => {
                      setStep(0);
                      setOpen(true);
                    }}
                    className="group mt-9 inline-flex items-center gap-3 rounded-pill bg-gradient-to-r from-gold via-gold to-gold-deep py-2 pl-7 pr-2 text-xs font-semibold uppercase tracking-[0.18em] text-white shadow-glow ring-1 ring-white/30 transition-transform duration-300 hover:-translate-y-0.5"
                  >
                    Buy a Gift Card
                    <span className="flex h-8 w-8 items-center justify-center rounded-full bg-ink/90 text-gold transition-transform duration-300 group-hover:translate-x-0.5">
                      <Image
                        src="/arrow.png"
                        alt=""
                        width={16}
                        height={16}
                        className="h-4 w-4 object-contain"
                      />
                    </span>
                  </button>
                </Reveal>
              </div>

              {/* Premium gift card visual */}
              <Reveal delay={2} className="order-1 flex justify-center lg:order-2 lg:justify-end">
                <div className="group relative w-full max-w-sm [perspective:1200px]">
                  <div className="pointer-events-none absolute inset-x-8 bottom-2 h-10 rounded-full bg-gold/25 blur-2xl" />
                  <div className="relative aspect-[1.6/1] w-full rotate-[-6deg] rounded-[1.4rem] bg-gradient-to-br from-gold via-gold to-gold-deep p-6 shadow-[0_45px_90px_-30px_rgba(245,118,30,0.6)] ring-1 ring-white/30 transition-transform duration-500 ease-out group-hover:rotate-0">
                    <div className="pointer-events-none absolute inset-0 overflow-hidden rounded-[1.4rem]">
                      <div className="absolute -inset-y-12 -left-1/3 w-1/2 rotate-12 bg-gradient-to-r from-transparent via-white/35 to-transparent" />
                    </div>

                    <div className="relative flex items-start justify-between">
                      <div>
                        <p className="font-display text-base font-bold uppercase leading-tight tracking-[0.12em] text-white">
                          Go4Foodie
                          <br />
                          Boston
                        </p>
                        <p className="mt-1 text-[9px] font-semibold uppercase tracking-[0.4em] text-white/75">
                          Gift Card
                        </p>
                      </div>
                      <span className="grid h-9 w-9 place-items-center rounded-full border border-white/60 font-display text-sm font-bold text-white">
                        G
                      </span>
                    </div>

                    <div className="relative mt-5 h-7 w-10 rounded-md bg-gradient-to-br from-[#ffd3a8] to-[#e0621a] ring-1 ring-ink/10">
                      <div className="absolute inset-x-2 top-1/2 h-px -translate-y-1/2 bg-ink/20" />
                      <div className="absolute inset-y-1.5 left-1/2 w-px -translate-x-1/2 bg-ink/20" />
                    </div>

                    <div className="relative mt-5 flex items-end justify-between">
                      <div>
                        <p className="text-[9px] font-semibold uppercase tracking-[0.3em] text-white/75">
                          Value
                        </p>
                        <p className="font-display text-2xl font-bold text-white">
                          $50 – $500
                        </p>
                      </div>
                      <p className="text-[9px] uppercase tracking-[0.25em] text-white/75">
                        No Expiry
                      </p>
                    </div>
                  </div>
                </div>
              </Reveal>
            </div>
          </div>
        </div>
      </section>

      {/* ---- Dialog: 4-stage purchase flow ---- */}
      {open && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-ink/70 backdrop-blur-sm"
            onClick={() => setOpen(false)}
            aria-hidden="true"
          />

          <div
            role="dialog"
            aria-modal="true"
            aria-label="Buy a Go4Foodie gift card"
            className="relative z-10 max-h-[92vh] w-full max-w-5xl overflow-y-auto overflow-x-hidden rounded-[1.5rem] bg-ink p-6 shadow-float ring-1 ring-cream/10 sm:p-10"
          >
            <div className="pointer-events-none absolute -right-24 top-0 h-72 w-72 rounded-full bg-gold/15 blur-[110px]" />

            {/* close */}
            <button
              type="button"
              onClick={() => setOpen(false)}
              aria-label="Close"
              className="absolute right-4 top-4 z-10 grid h-9 w-9 place-items-center rounded-full border border-cream/20 text-cream transition-colors hover:border-gold hover:text-gold"
            >
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path
                  d="M6 6l12 12M18 6L6 18"
                  stroke="currentColor"
                  strokeWidth="2"
                  fill="none"
                  strokeLinecap="round"
                />
              </svg>
            </button>

            {step < 4 ? (
              <div className="relative grid gap-8 lg:grid-cols-[0.8fr_1fr]">
                {/* Left: live card preview */}
                <div className="hidden flex-col gap-5 lg:flex">
                  <div className="relative aspect-[1.6/1] w-full rounded-[1.4rem] bg-gradient-to-br from-gold via-gold to-gold-deep p-7 shadow-[0_40px_80px_-30px_rgba(245,118,30,0.55)] ring-1 ring-white/30">
                    <div className="pointer-events-none absolute inset-0 overflow-hidden rounded-[1.25rem]">
                      <div className="absolute -inset-y-10 -left-1/3 w-1/2 rotate-12 bg-gradient-to-r from-transparent via-white/35 to-transparent" />
                    </div>
                    <div className="relative flex items-start justify-between">
                      <div>
                        <p className="font-display text-sm font-bold uppercase leading-tight tracking-[0.12em] text-white">
                          Go4Foodie
                          <br />
                          Boston
                        </p>
                        <p className="mt-0.5 text-[9px] font-semibold uppercase tracking-[0.4em] text-white/75">
                          Gift Card
                        </p>
                      </div>
                      <span className="grid h-8 w-8 place-items-center rounded-full border border-white/60 font-display text-xs font-bold text-white">
                        G
                      </span>
                    </div>
                    <div className="relative mt-6 h-8 w-12 rounded-md bg-gradient-to-br from-[#ffd3a8] to-[#e0621a] ring-1 ring-ink/10">
                      <div className="absolute inset-x-2 top-1/2 h-px -translate-y-1/2 bg-ink/20" />
                      <div className="absolute inset-y-1.5 left-1/2 w-px -translate-x-1/2 bg-ink/20" />
                    </div>
                    <div className="relative mt-6 flex items-end justify-between">
                      <div>
                        <p className="text-[9px] font-semibold uppercase tracking-[0.3em] text-white/75">
                          Value
                        </p>
                        <p className="font-display text-3xl font-bold text-white">
                          ${form.amount}.00
                        </p>
                      </div>
                      <p className="text-right font-display text-[10px] uppercase tracking-[0.2em] text-white/80">
                        {form.recipientType === "someone" && form.recipientName
                          ? `To ${form.recipientName}`
                          : "No Expiry"}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-2xl border border-cream/10 bg-ink-soft/60 p-4 text-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-cream/55">Subtotal</span>
                      <span className="font-semibold text-cream">
                        ${total}.00
                      </span>
                    </div>
                    <div className="mt-1.5 flex items-center justify-between text-xs text-cream/45">
                      <span>
                        {form.quantity} × ${form.amount} card
                        {form.quantity > 1 ? "s" : ""}
                      </span>
                      <span>No fees</span>
                    </div>
                  </div>
                </div>

                {/* Right: stage form */}
                <div>
                  <Stepper step={step} />

                  {/* Stage 0 — Amount */}
                  {step === 0 && (
                    <div className="mt-7 animate-fade-up">
                      <h3 className="font-display text-2xl text-cream">
                        Gift card or coupon?
                      </h3>
                      <p className="mt-1 text-sm text-cream/55">
                        For use at Go4Foodie — dining, wine &amp;
                        events.
                      </p>
                      <div className="mt-5">
                        <Toggle<"GIFT_CARD" | "COUPON">
                          value={form.kind}
                          onChange={(v) => set("kind", v)}
                          options={[
                            {
                              value: "GIFT_CARD",
                              label: "Gift Card",
                              icon: (
                                <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
                                  <path d="M20 12v9H4v-9M2 7h20v5H2zM12 21V7m0 0H8.5a2.5 2.5 0 1 1 2.5-2.5V7zm0 0h3.5a2.5 2.5 0 1 0-2.5-2.5V7z" />
                                </svg>
                              ),
                            },
                            {
                              value: "COUPON",
                              label: "Coupon",
                              icon: (
                                <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
                                  <path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2 2 2 0 0 0 0 4 2 2 0 0 1-2 2H5a2 2 0 0 1-2-2 2 2 0 0 0 0-4z" />
                                  <path d="M15 6v12" strokeDasharray="2 2" />
                                </svg>
                              ),
                            },
                          ]}
                        />
                      </div>
                      <p className="mb-3 mt-6 block text-xs font-semibold uppercase tracking-[0.18em] text-cream/60">
                        Choose an amount
                      </p>
                      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                        {AMOUNTS.map((value) => (
                          <button
                            key={value}
                            type="button"
                            onClick={() => set("amount", value)}
                            aria-pressed={form.amount === value}
                            className={`rounded-xl border py-4 font-display text-lg font-bold transition-all duration-300 ${
                              form.amount === value
                                ? "border-gold bg-gold text-white shadow-glow"
                                : "border-cream/20 text-cream hover:border-gold/60 hover:text-gold"
                            }`}
                          >
                            ${value}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Stage 1 — Details */}
                  {step === 1 && (
                    <div className="mt-7 animate-fade-up">
                      <h3 className="font-display text-2xl text-cream">
                        Who is it for?
                      </h3>

                      <div className="mt-5">
                        <Toggle<"someone" | "self">
                          value={form.recipientType}
                          onChange={(v) => set("recipientType", v)}
                          options={[
                            {
                              value: "someone",
                              label: "Someone else",
                              icon: (
                                <svg
                                  viewBox="0 0 24 24"
                                  className="h-4 w-4"
                                  fill="none"
                                  stroke="currentColor"
                                  strokeWidth="1.6"
                                  aria-hidden="true"
                                >
                                  <path
                                    d="M20 12v9H4v-9M2 7h20v5H2zM12 21V7m0 0H8.5a2.5 2.5 0 1 1 2.5-2.5V7zm0 0h3.5a2.5 2.5 0 1 0-2.5-2.5V7z"
                                    strokeLinejoin="round"
                                  />
                                </svg>
                              ),
                            },
                            {
                              value: "self",
                              label: "Yourself",
                              icon: (
                                <svg
                                  viewBox="0 0 24 24"
                                  className="h-4 w-4"
                                  fill="none"
                                  stroke="currentColor"
                                  strokeWidth="1.6"
                                  aria-hidden="true"
                                >
                                  <circle cx="12" cy="8" r="3.2" />
                                  <path
                                    d="M5 20a7 7 0 0 1 14 0"
                                    strokeLinecap="round"
                                  />
                                </svg>
                              ),
                            },
                          ]}
                        />
                      </div>

                      <div className="mt-5 grid gap-5 sm:grid-cols-2">
                        <div>
                          <label className={labelClass}>Quantity</label>
                          <select
                            value={form.quantity}
                            onChange={(e) =>
                              set("quantity", Number(e.target.value))
                            }
                            className={`${fieldClass} appearance-none`}
                          >
                            {QUANTITIES.map((q) => (
                              <option key={q} value={q} className="bg-ink-soft">
                                {q}
                              </option>
                            ))}
                          </select>
                        </div>
                        <div>
                          <label className={labelClass}>Your name</label>
                          <input
                            value={form.yourName}
                            onChange={(e) => set("yourName", e.target.value)}
                            placeholder="Jane Doe"
                            className={fieldClass}
                          />
                        </div>
                        {form.recipientType === "someone" && (
                          <div className="sm:col-span-2">
                            <label className={labelClass}>Recipient name</label>
                            <input
                              value={form.recipientName}
                              onChange={(e) =>
                                set("recipientName", e.target.value)
                              }
                              placeholder="Alex Smith"
                              className={fieldClass}
                            />
                          </div>
                        )}
                        <div className="sm:col-span-2">
                          <label className={labelClass}>
                            Message{" "}
                            <span className="font-normal text-cream/35">
                              optional
                            </span>
                          </label>
                          <textarea
                            value={form.message}
                            onChange={(e) => set("message", e.target.value)}
                            rows={3}
                            placeholder="Add a personal note…"
                            className={`${fieldClass} resize-none`}
                          />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Stage 2 — Delivery */}
                  {step === 2 && (
                    <div className="mt-7 animate-fade-up">
                      <h3 className="font-display text-2xl text-cream">
                        How should we deliver it?
                      </h3>

                      <div className="mt-5">
                        <Toggle<"email" | "print">
                          value={form.delivery}
                          onChange={(v) => set("delivery", v)}
                          options={[
                            {
                              value: "email",
                              label: "By email",
                              icon: (
                                <svg
                                  viewBox="0 0 24 24"
                                  className="h-4 w-4"
                                  fill="none"
                                  stroke="currentColor"
                                  strokeWidth="1.6"
                                  aria-hidden="true"
                                >
                                  <rect
                                    x="3"
                                    y="5"
                                    width="18"
                                    height="14"
                                    rx="2"
                                  />
                                  <path
                                    d="M4 7l8 5 8-5"
                                    strokeLinecap="round"
                                  />
                                </svg>
                              ),
                            },
                            {
                              value: "print",
                              label: "Print",
                              icon: (
                                <svg
                                  viewBox="0 0 24 24"
                                  className="h-4 w-4"
                                  fill="none"
                                  stroke="currentColor"
                                  strokeWidth="1.6"
                                  aria-hidden="true"
                                >
                                  <path
                                    d="M6 9V3h12v6M6 18H4a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-2M6 14h12v7H6z"
                                    strokeLinejoin="round"
                                  />
                                </svg>
                              ),
                            },
                          ]}
                        />
                      </div>

                      {form.delivery === "email" ? (
                        <div className="mt-5 space-y-5">
                          <div className="grid gap-5 sm:grid-cols-[1fr_auto]">
                            <div>
                              <label className={labelClass}>
                                Send the gift card to
                              </label>
                              <input
                                type="email"
                                value={form.email}
                                onChange={(e) => set("email", e.target.value)}
                                placeholder="recipient@email.com"
                                className={fieldClass}
                              />
                            </div>
                            <div>
                              <label className={labelClass}>When</label>
                              <select
                                value={form.timing}
                                onChange={(e) => set("timing", e.target.value)}
                                className={`${fieldClass} appearance-none`}
                              >
                                {TIMINGS.map((t) => (
                                  <option
                                    key={t}
                                    value={t}
                                    className="bg-ink-soft"
                                  >
                                    {t}
                                  </option>
                                ))}
                              </select>
                            </div>
                          </div>
                          {form.timing === "Send on a future date" && (
                            <div className="sm:max-w-xs">
                              <label className={labelClass}>
                                Delivery date
                              </label>
                              <input
                                type="date"
                                value={form.sendDate}
                                onChange={(e) =>
                                  set("sendDate", e.target.value)
                                }
                                className={`${fieldClass} [color-scheme:dark]`}
                              />
                            </div>
                          )}
                        </div>
                      ) : (
                        <p className="mt-5 rounded-xl border border-cream/10 bg-ink-soft/60 px-4 py-4 text-sm text-cream/70">
                          A beautifully designed printable PDF will be generated
                          after checkout — ready to gift in person.
                        </p>
                      )}
                    </div>
                  )}

                  {/* Stage 3 — Review */}
                  {step === 3 && (
                    <div className="mt-7 animate-fade-up">
                      <h3 className="font-display text-2xl text-cream">
                        Review &amp; confirm
                      </h3>
                      <dl className="mt-5 divide-y divide-cream/10 rounded-2xl border border-cream/10 bg-ink/40 px-5">
                        {[
                          ["Amount", `$${form.amount} × ${form.quantity}`],
                          ["From", form.yourName],
                          [
                            "To",
                            form.recipientType === "self"
                              ? "Yourself"
                              : form.recipientName,
                          ],
                          [
                            "Delivery",
                            form.delivery === "email"
                              ? `Email · ${form.timing}${
                                  form.timing === "Send on a future date" &&
                                  form.sendDate
                                    ? ` (${form.sendDate})`
                                    : ""
                                }`
                              : "Printable PDF",
                          ],
                          ...(form.delivery === "email"
                            ? [["Email", form.email] as [string, string]]
                            : []),
                          ["Message", form.message || "—"],
                        ].map(([k, v]) => (
                          <div
                            key={k}
                            className="flex items-center justify-between gap-6 py-3.5 text-sm"
                          >
                            <dt className="text-cream/55">{k}</dt>
                            <dd className="text-right font-medium text-cream">
                              {v}
                            </dd>
                          </div>
                        ))}
                        <div className="flex items-center justify-between gap-6 py-4 text-base">
                          <dt className="font-semibold text-cream">Total</dt>
                          <dd className="font-display text-xl font-bold text-gold">
                            ${total}.00
                          </dd>
                        </div>
                      </dl>
                    </div>
                  )}

                  {/* Nav */}
                  <div className="mt-8 flex items-center justify-between gap-3">
                    {step > 0 ? (
                      <button
                        type="button"
                        onClick={() => setStep((s) => s - 1)}
                        className="btn-ghost"
                      >
                        Back
                      </button>
                    ) : (
                      <span />
                    )}
                    {step < 3 ? (
                      <button
                        type="button"
                        disabled={!stepValid}
                        onClick={() => setStep((s) => s + 1)}
                        className="btn-primary disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        Continue
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={purchase}
                        disabled={submitting}
                        className="btn-primary disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {submitting ? "Processing…" : `Complete Purchase — $${total}`}
                      </button>
                    )}
                  </div>
                  {error && (
                    <p className="mt-4 rounded-xl border border-brand/40 bg-brand/10 px-4 py-3 text-sm text-cream">
                      {error}
                    </p>
                  )}
                </div>
              </div>
            ) : (
              /* Success */
              <div className="relative flex min-h-[420px] flex-col items-center justify-center text-center animate-fade-up">
                <Confetti />
                <span className="relative grid h-20 w-20 place-items-center rounded-full bg-gold/15 text-gold ring-1 ring-gold/40">
                  <svg
                    viewBox="0 0 24 24"
                    className="h-9 w-9"
                    aria-hidden="true"
                  >
                    <path
                      d="M5 13l4 4L19 7"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      fill="none"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </span>
                <h3 className="mt-6 font-display text-3xl text-cream">
                  {form.kind === "COUPON" ? "Coupon purchased" : "Gift card purchased"}
                </h3>
                <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                  {form.delivery === "email" ? (
                    <>
                      A {form.quantity > 1 ? `${form.quantity} × ` : ""}$
                      {form.amount} gift card is on its way to{" "}
                      <span className="text-cream">{form.email}</span>.
                    </>
                  ) : (
                    <>
                      Your printable ${form.amount} gift card
                      {form.quantity > 1 ? "s are" : " is"} ready to download.
                    </>
                  )}
                </p>

                <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                  <p className="text-xs uppercase tracking-[0.2em] text-cream/50">
                    {form.kind === "COUPON" ? "Coupon code" : "Gift card code"}
                  </p>
                  <p className="mt-1 font-mono text-2xl font-bold tracking-[0.2em] text-gold">
                    {reference}
                  </p>
                  <p className="mt-2 text-cream/70">
                    ${form.amount}.00 · {form.email ? `sent to ${form.email}` : "ready to use"}
                  </p>
                </div>

                <div className="mt-8 flex flex-wrap justify-center gap-4">
                  <button
                    type="button"
                    onClick={() => setOpen(false)}
                    className="btn-ghost"
                  >
                    Done
                  </button>
                  <button type="button" onClick={reset} className="btn-primary">
                    Buy Another
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
