import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Client formatting helpers — ports of the admin's JS (formatCurrency/bizMoney, fmtDate, bizDate,
/// toCsv/bizCsv, bizNiceAxis). Dates render in the browser's local timezone, like the JS did.

/// Intl en-US USD, max 0 fraction digits by default: 15750 → "$15,750" (POS bills too — parity).
String money(num? v, {int maxFrac = 0, int? minFrac}) {
  final f = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: maxFrac);
  f.minimumFractionDigits = minFrac ?? math.min(2, maxFrac);
  f.maximumFractionDigits = maxFrac;
  return f.format(v ?? 0);
}

/// Number#toLocaleString('en-US').
String grouped(num? v) => NumberFormat.decimalPattern('en_US').format(v ?? 0);

DateTime? parseDate(dynamic v) {
  if (v == null || v == '') return null;
  if (v is DateTime) return v.toLocal();
  final s = v.toString();
  // "YYYY-MM-DD" is UTC midnight in JS (new Date('2026-01-05')).
  final d = DateTime.tryParse(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ? '${s}T00:00:00Z' : s);
  return d?.toLocal();
}

/// fmtDate(value, pattern) — tokens: yyyy EEE MMM MM dd d hh h HH mm a and 'literal'.
/// Patterns used: `h:mm a`, `MMM d, h:mm a`, `EEE, MMM d`, `MMM d`, `EEE, MMM d, yyyy`, `EEE, MMM d · h:mm a`.
String fmtDate(dynamic value, String pattern) {
  final d = parseDate(value);
  if (d == null) return '';
  try {
    return DateFormat(pattern, 'en_US').format(d);
  } catch (_) {
    return d.toString();
  }
}

/// Duration like the floor cards: `Xh Ym` or `Ym`.
String durationSince(dynamic openedAt, [DateTime? now]) {
  final d = parseDate(openedAt);
  if (d == null) return '';
  final mins = math.max(0, (now ?? DateTime.now()).difference(d).inMinutes);
  final h = mins ~/ 60;
  final m = mins % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Every cell double-quoted, `"` escaped as `""`, rows joined with "\n".
String toCsv(List<List<Object?>> rows) =>
    rows.map((r) => r.map((c) => '"${(c ?? '').toString().replaceAll('"', '""')}"').join(',')).join('\n');

/// Trigger a browser download.
void downloadBytes(String filename, List<int> bytes, String mime) {
  final blob = web.Blob(<JSAny>[Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

void downloadText(String filename, String text, String mime) => downloadBytes(filename, utf8.encode(text), mime);

void downloadCsv(String filename, List<List<Object?>> rows) => downloadText(filename, toCsv(rows), 'text/csv;charset=utf-8');

/// Open a popup with [html] and print it (KOT, invoices, QR print, PDF exports used window.print()).
void printHtml(String html, {int width = 400, int height = 680}) {
  final w = web.window.open('', '_blank', 'width=$width,height=$height');
  if (w == null) return;
  w.document.open();
  w.document.write(html.toJS);
  w.document.close();
}

/// bizNiceAxis(max): 5 ticks, step = ceil((max/4)/unit)*unit, unit = 0.05·10^(floor(log10(max/4))+1).
({double max, double step}) niceAxis(num max) {
  if (max <= 0) return (max: 4, step: 1);
  final raw = max / 4;
  final unit = 0.05 * math.pow(10, (math.log(raw) / math.ln10).floor() + 1);
  final step = (raw / unit).ceil() * unit;
  return (max: step * 4, step: step.toDouble());
}

/// HTML-escape for print templates.
String esc(Object? s) => const HtmlEscape().convert('${s ?? ''}');
