{{--
  Shared client helpers for the business pages (staff, customers, gift cards, transactions,
  inventory, reports, outlets). Include once per page: <x-biz.helpers />
  Ports of utils.ts formatCurrency / formatDate (date-fns patterns used by the Next admin)
  and the CSV download used by the managers' Export buttons.
--}}
@once
    @push('scripts')
        <script>
            (() => {
                const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

                /** formatCurrency(value, opts) — Intl USD, max 0 fraction digits by default. */
                window.bizMoney = (v, opts = {}) =>
                    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0, ...opts })
                        .format(Number(v || 0));

                /** date-fns format() for the patterns the admin uses: MMM d, yyyy · MMM d · MMM d, h:mm a */
                window.bizDate = (value, pattern = 'MMM d, yyyy') => {
                    if (!value) return '';
                    const d = new Date(value);
                    if (isNaN(d.getTime())) return '';
                    const h = d.getHours() % 12 || 12;
                    const mm = String(d.getMinutes()).padStart(2, '0');
                    const ap = d.getHours() < 12 ? 'AM' : 'PM';
                    return pattern
                        .replace('yyyy', '\u0001')
                        .replace('MMM', '\u0002')
                        .replace('h:mm a', '\u0003')
                        .replace(/\bd\b/, String(d.getDate()))
                        .replace('\u0001', String(d.getFullYear()))
                        .replace('\u0002', MONTHS[d.getMonth()])
                        .replace('\u0003', `${h}:${mm} ${ap}`);
                };

                /** Quote every cell, join with commas, download as a .csv file. */
                window.bizCsv = (filename, rows) => {
                    const csv = rows.map((r) => r.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
                    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = filename;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    URL.revokeObjectURL(url);
                };

                /** recharts getNiceTickValues for a [0, max] domain with 5 ticks:
                    step = rough step rounded up to a multiple of 0.05·10^digits. */
                window.bizNiceAxis = (max) => {
                    if (!(max > 0)) return { max: 4, step: 1 };
                    const rough = max / 4;
                    const unit = 0.05 * Math.pow(10, Math.floor(Math.log10(rough)) + 1);
                    const step = Math.ceil(rough / unit) * unit;
                    return { max: step * 4, step };
                };

                window.bizInitials = (name) =>
                    String(name || '').split(' ').map((p) => p[0] || '').slice(0, 2).join('');

                window.BIZ_AVATAR_COLORS = ['bg-accent', 'bg-[#0b5e46]', 'bg-info', 'bg-gold', 'bg-[#9a6cf1]'];

                /** Re-render lucide icons after Alpine has patched the DOM. */
                window.bizIcons = () => requestAnimationFrame(() => window.renderIcons && window.renderIcons());
            })();
        </script>
    @endpush
@endonce
