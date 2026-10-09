import 'package:intl/intl.dart';

final _money = NumberFormat.simpleCurrency(name: 'USD');
final _compact = NumberFormat.compactSimpleCurrency(name: 'USD');

String money(num? v) => _money.format(v ?? 0);
String moneyCompact(num? v) => _compact.format(v ?? 0);

num asNum(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

String fmtDate(Object? iso, [String pattern = 'EEE, d MMM']) {
  final d = parseDate(iso);
  return d == null ? '—' : DateFormat(pattern).format(d);
}

String fmtDateTime(Object? iso) => fmtDate(iso, 'd MMM · h:mm a');
String fmtTime(Object? iso) => fmtDate(iso, 'h:mm a');

/// "18:30" → "6:30 PM"
String fmtSlot(String? hhmm) {
  if (hhmm == null || !hhmm.contains(':')) return hhmm ?? '';
  final p = hhmm.split(':');
  final d = DateTime(2000, 1, 1, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
  return DateFormat('h:mm a').format(d);
}

String ago(Object? iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(d);
}

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// "WAITING_PAYMENT" → "Waiting Payment"
String humanize(String? v) {
  if (v == null || v.isEmpty) return '';
  return v
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
