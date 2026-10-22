import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web/web.dart' as web;

import '../core/theme.dart';
import 'ui.dart';

/// Extra primitives shared by the operations pages (orders, menu, reservations, tables, floor, POS).

// ---------------------------------------------------------------- json helpers

typedef Json = Map<String, dynamic>;

Json asJson(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Json> asJsonList(dynamic v) => v is List ? v.map(asJson).toList() : <Json>[];

/// JS-ish string coercion (null → '').
String str(dynamic v) => v == null ? '' : '$v';

/// JS `Number(v) || 0`.
num toNum(dynamic v) {
  if (v is num) return v.isNaN ? 0 : v;
  final p = num.tryParse('${v ?? ''}'.trim());
  return p == null || p.isNaN ? 0 : p;
}

/// Present and non-empty (JS truthy for strings/numbers we use).
bool has(dynamic v) => v != null && v != '' && v != false;

// ---------------------------------------------------------------- modal sync

/// Pages keep their state in a State object and show modals with [showAppModal]; modal content
/// wraps itself in a [ValueListenableBuilder] on this notifier so it re-renders on page updates.
class Rev extends ValueNotifier<int> {
  Rev() : super(0);
  void bump() => value++;
}

Widget synced(Rev rev, Widget Function() build) => ValueListenableBuilder<int>(valueListenable: rev, builder: (_, _, _) => build());

// ---------------------------------------------------------------- small text bits

/// `text-xs uppercase tracking-wide text-fg-muted` caption.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.bold = false, this.bottom = 8});
  final String text;
  final bool bold;
  final double bottom;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: .6, color: context.c.fgMuted, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      );
}

/// Uppercase 10px pill (orders table badges).
class TinyPill extends StatelessWidget {
  const TinyPill(this.text, {super.key, required this.fg, required this.bg, this.uppercase = true, this.size = 10});
  final String text;
  final Color fg, bg;
  final bool uppercase;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size > 10 ? 10 : 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(uppercase ? text.toUpperCase() : text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, letterSpacing: uppercase ? .5 : 0, color: fg)),
      );
}

const gatewayBlue = Color(0xFF3395FF);

/// Bordered box with a small muted label and a value (detail grids).
class DetailBox extends StatelessWidget {
  const DetailBox(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: context.c.border), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.c.fgMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// Two-column grid (`grid grid-cols-2 gap-3`). [stretch] equalises row heights (detail boxes).
class TwoCol extends StatelessWidget {
  const TwoCol({super.key, required this.children, this.gap = 12, this.stretch = false});
  final List<Widget> children;
  final double gap;
  final bool stretch;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      final row = Row(crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: [
        Expanded(child: children[i]),
        SizedBox(width: gap),
        Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
      ]);
      rows.add(stretch ? IntrinsicHeight(child: row) : row);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Bordered rounded-xl box.
class Boxed extends StatelessWidget {
  const Boxed({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor, this.radius = 12});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color, borderColor;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, border: Border.all(color: borderColor ?? context.c.border), borderRadius: BorderRadius.circular(radius)),
        child: child,
      );
}

/// Red "This order was canceled." box.
class DangerNote extends StatelessWidget {
  const DangerNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.dangerSoft, border: Border.all(color: c.danger.withValues(alpha: .4)), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(LucideIcons.x, size: 16, color: c.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.danger))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- stepper

/// Step-wise status progress (orders + reservations detail): done = check, current = ring.
class FlowStepper extends StatelessWidget {
  const FlowStepper({super.key, required this.labels, required this.current});
  final List<String> labels;

  /// Index of the current step; -1 when cancelled (all todo).
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String step(int i) => current < 0 ? 'todo' : (i < current ? 'done' : (i == current ? 'current' : 'todo'));
    Widget dot(int i) {
      final st = step(i);
      final on = st != 'todo';
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? c.accent : c.surface,
            border: Border.all(color: on ? c.accent : c.border),
            boxShadow: st == 'current' ? [BoxShadow(color: c.accentSoft, spreadRadius: 4)] : null,
          ),
          alignment: Alignment.center,
          child: st == 'done'
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : c.fgMuted)),
        ),
        const SizedBox(height: 6),
        Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2, color: on ? c.fg : c.fgMuted)),
      ]);
    }

    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      children.add(dot(i));
      if (i < labels.length - 1) {
        children.add(Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 4, right: 4, top: 15),
            height: 2,
            decoration: BoxDecoration(color: i < current ? c.accent : c.border, borderRadius: BorderRadius.circular(2)),
          ),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

// ---------------------------------------------------------------- inputs

/// Compact input with a small muted label on top (floor / POS / reservation edit forms).
class SmallField extends StatelessWidget {
  const SmallField({super.key, required this.label, required this.controller, this.hint, this.number = false, this.maxLines = 1, this.onChanged, this.readOnly = false, this.onTap, this.suffix});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool number, readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: TextStyle(fontSize: 12, color: context.c.fgMuted))),
        AppInput(controller: controller, hint: hint, number: number, maxLines: maxLines, onChanged: onChanged, readOnly: readOnly, onTap: onTap, suffix: suffix),
      ]);
}

/// Plain `.input`-styled text field.
class AppInput extends StatelessWidget {
  const AppInput({super.key, required this.controller, this.hint, this.number = false, this.maxLines = 1, this.onChanged, this.readOnly = false, this.onTap, this.suffix, this.textAlign = TextAlign.start, this.dense = false});
  final TextEditingController controller;
  final String? hint;
  final bool number, readOnly, dense;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? suffix;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        onChanged: onChanged,
        textAlign: textAlign,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] : null,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: suffix,
          contentPadding: dense ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : null,
        ),
      );
}

/// Small green/grey availability switch (menu table).
class MiniSwitch extends StatelessWidget {
  const MiniSwitch({super.key, required this.value, required this.onTap});
  final bool value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: value ? c.success : c.border, borderRadius: BorderRadius.circular(999)),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))]),
          ),
        ),
      ),
    );
  }
}

/// Text-style link button (e.g. "Clear date", "Save adjustments", "Edit reservation").
class LinkBtn extends StatelessWidget {
  const LinkBtn(this.label, {super.key, this.onTap, this.icon, this.color, this.size = 12, this.weight = FontWeight.w500});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double size;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) {
    final col = color ?? context.c.fgMuted;
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: size + 2, color: col), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: size, fontWeight: weight, color: col)),
          ]),
        ),
      ),
    );
  }
}

/// Square bordered − / + button (POS cart and bill lines).
class QtyBtn extends StatelessWidget {
  const QtyBtn(this.label, {super.key, this.onTap, this.size = 24, this.hover});
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? hover;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: InkWell(
        onTap: onTap,
        hoverColor: (hover ?? c.accent).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: TextStyle(fontSize: size > 20 ? 14 : 12, height: 1, color: size > 20 ? c.fg : c.fgMuted)),
        ),
      ),
    );
  }
}

/// Responsive column count by available width (tailwind-like breakpoints on the content box).
int colsFor(double width, {int base = 2, int sm = 3, int lg = 4, int? xl}) {
  // Content width ≈ viewport − sidebar(72) − padding(48).
  final vw = width + 120;
  if (xl != null && vw >= 1280) return xl;
  if (vw >= 1024) return lg;
  if (vw >= 640) return sm;
  return base;
}

/// Fixed-column grid with equal widths.
class ColsGrid extends StatelessWidget {
  const ColsGrid({super.key, required this.cols, required this.children, this.gap = 16});
  final int Function(double width) cols;
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final k = cols(box.maxWidth).clamp(1, 12);
        final w = (box.maxWidth - gap * (k - 1)) / k;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// Network image that degrades gracefully (thumbs, previews).
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, required this.size, this.radius = 8});
  final String url;
  final double size, radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: url.isEmpty
              ? ColoredBox(color: context.c.bg)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => ColoredBox(color: context.c.bg),
                ),
        ),
      );
}

/// Date / time picking for the reservation filter and edit form (values like `<input type=date|time>`).
Future<String?> pickDateValue(BuildContext context, String current) async {
  final init = DateTime.tryParse(current) ?? DateTime.now();
  final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(2000), lastDate: DateTime(2100));
  if (d == null) return null;
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<String?> pickTimeValue(BuildContext context, String current) async {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(current);
  final init = m != null ? TimeOfDay(hour: int.parse(m.group(1)!) % 24, minute: int.parse(m.group(2)!) % 60) : TimeOfDay.now();
  final t = await showTimePicker(context: context, initialTime: init);
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// `<input type=date>` display value (mm/dd/yyyy).
String dateInputLabel(String v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
  return m == null ? 'mm/dd/yyyy' : '${m.group(2)}/${m.group(3)}/${m.group(1)}';
}

// ---------------------------------------------------------------- QR

/// QR PNG like `QRCode.toDataURL(text, {width: size, margin: 1, errorCorrectionLevel: 'M'})`:
/// white background, 1-module quiet zone.
Future<Uint8List> qrPng(String data, int size) async {
  final qr = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
  final modules = qr.moduleCount;
  final cell = size / (modules + 2);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), Paint()..color = Colors.white);
  canvas.translate(cell, cell);
  QrPainter.withQr(qr: qr, gapless: true).paint(canvas, Size.square(cell * modules));
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<String> qrDataUrl(String data, int size) async => 'data:image/png;base64,${base64Encode(await qrPng(data, size))}';

/// On-screen QR (white background, margin 1 module).
class QrBox extends StatelessWidget {
  const QrBox(this.data, {super.key, required this.size});
  final String data;
  final double size;
  @override
  Widget build(BuildContext context) {
    final qr = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    final cell = size / (qr.moduleCount + 2);
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(cell),
      child: CustomPaint(painter: QrPainter.withQr(qr: qr, gapless: true)),
    );
  }
}

// ---------------------------------------------------------------- file picking (menu image upload)

class PickedFile {
  PickedFile(this.bytes, this.name, this.type, this.size);
  final Uint8List bytes;
  final String name, type;
  final int size;
}

/// Hidden `<input type=file accept=image/*>`; resolves null when cancelled.
Future<PickedFile?> pickImageFile() {
  final done = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  web.document.body!.append(input);
  void finish(PickedFile? f) {
    if (!done.isCompleted) done.complete(f);
    input.remove();
  }

  Future<void> read() async {
    final f = input.files?.item(0);
    if (f == null) return finish(null);
    try {
      final buf = await f.arrayBuffer().toDart;
      finish(PickedFile(buf.toDart.asUint8List(), f.name, f.type, f.size));
    } catch (_) {
      finish(null);
    }
  }

  input.addEventListener('change', ((web.Event _) {
    read();
  }).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}

/// Open a URL in a new tab (target=_blank rel=noopener).
void openNewTab(String url) => web.window.open(url, '_blank', 'noopener,noreferrer');

/// Status badge with the shared tone map and an explicit label (floor state labels etc.).
Widget toneBadge(BuildContext context, String status, String label, {double size = 12, bool dot = false, EdgeInsets? padding}) {
  final t = toneColors(context, statusTones[status] ?? Tone.muted);
  return Container(
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
      Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: t.fg)),
    ]),
  );
}

/// JS `String(number)`: 26 → "26", 12.5 → "12.5".
String jsNum(dynamic v) {
  if (v == null) return '';
  if (v is num) return v == v.truncate() && v.isFinite ? '${v.toInt()}' : '$v';
  return '$v';
}

/// Open the print popup synchronously (inside the click, so popup blockers allow it) and
/// write [html] once it is ready — like `window.open()` then `await qr()` in the Blade page.
Future<void> printHtmlAsync(Future<String> html, {int width = 400, int height = 680}) async {
  final w = web.window.open('', '_blank', 'width=$width,height=$height');
  if (w == null) return;
  final doc = await html;
  w.document.open();
  w.document.write(doc.toJS);
  w.document.close();
}
