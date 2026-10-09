// Rating UI primitive — reused by hero card and menu cards (§5/§2).

function Star({ fill = 1 }) {
  // fill: 1 = full, 0.5 = half, 0 = empty
  return (
    <svg viewBox="0 0 20 20" className="h-3.5 w-3.5" aria-hidden="true">
      <defs>
        <linearGradient id={`half-${fill}`}>
          <stop offset="50%" stopColor="currentColor" />
          <stop offset="50%" stopColor="rgba(255,255,255,0.18)" />
        </linearGradient>
      </defs>
      <path
        d="M10 1.5l2.6 5.27 5.82.85-4.21 4.1.99 5.78L10 14.77l-5.2 2.73.99-5.78L1.58 7.62l5.82-.85L10 1.5z"
        fill={fill === 1 ? 'currentColor' : fill === 0.5 ? `url(#half-${fill})` : 'rgba(255,255,255,0.18)'}
      />
    </svg>
  );
}

export default function Stars({ rating = 5, showValue = true, className = '' }) {
  const stars = Array.from({ length: 5 }, (_, i) => {
    const diff = rating - i;
    return diff >= 1 ? 1 : diff >= 0.5 ? 0.5 : 0;
  });

  return (
    <span className={`stars ${className}`} aria-label={`Rated ${rating} out of 5`}>
      {stars.map((f, i) => (
        <Star key={i} fill={f} />
      ))}
      {showValue && (
        <span className="ml-1 text-xs font-semibold text-cream/80">{rating.toFixed(1)}</span>
      )}
    </span>
  );
}
