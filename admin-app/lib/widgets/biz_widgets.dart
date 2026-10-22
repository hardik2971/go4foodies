import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme.dart';
import 'ui.dart';

/// Shared widgets/helpers for the business managers (staff, customers, gift cards, inventory,
/// outlets, settings…) — ports of components/biz/* (helpers, stat, modal) and the repeated
/// Tailwind patterns in those Blade views.

// ---------------------------------------------------------------- helpers

/// JS `String(number)` / template-literal number: 5 → "5", 2.5 → "2.5".
String jsNum(num? v) {
  if (v == null) return '0';
  if (v is int) return '$v';
  if (v.isFinite && v == v.truncateToDouble()) return v.toInt().toString();
  return v.toString();
}

/// JS Math.round (half-up), as used by Format::round.
int jsRound(num v) => (v + 0.5).floor();

/// The `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` email check used by the biz forms.
bool isEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

num numOf(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

/// Monospace (font-mono) for codes / payment ids.
TextStyle mono({double size = 12, FontWeight weight = FontWeight.w600, Color? color, double? letterSpacing}) =>
    GoogleFonts.robotoMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

/// BIZ_AVATAR_COLORS = [accent, #0b5e46, info, gold, #9a6cf1] (by row index).
Color bizAvatarColor(BuildContext context, int i) {
  final c = context.c;
  final colors = [c.accent, const Color(0xFF0B5E46), c.info, c.gold, const Color(0xFF9A6CF1)];
  return colors[i % colors.length];
}

/// Round initials avatar (bizInitials + BIZ_AVATAR_COLORS).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, required this.index, this.size = 36, this.fontSize = 12});
  final String name;
  final int index;
  final double size, fontSize;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bizAvatarColor(context, index), shape: BoxShape.circle),
        child: Text(bizInitials(name), style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600)),
      );
}

/// window.bizInitials — first letters of the first two space-separated words (case kept).
String bizInitials(String? name) {
  final parts = (name ?? '').split(' ');
  return parts.map((p) => p.isEmpty ? '' : p[0]).take(2).join();
}

// ---------------------------------------------------------------- layout

/// Stats row: `grid grid-cols-2 gap-4 lg:grid-cols-4`.
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.of(context).size.width >= 1024 ? 4 : 2;
    return LayoutBuilder(builder: (context, box) {
      const gap = 16.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

/// Toolbar: `flex flex-wrap items-center justify-between gap-3`.
class BizToolbar extends StatelessWidget {
  const BizToolbar({super.key, required this.left, required this.right});
  final Widget left;
  final List<Widget> right;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          left,
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: right),
        ],
      );
}

/// Vertical stack with `space-y-*` gaps.
class Gap extends StatelessWidget {
  const Gap({super.key, required this.children, this.gap = 20, this.crossAxisAlignment = CrossAxisAlignment.stretch});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ],
      );
}

/// `grid grid-cols-N gap-4` row of equal columns (forms).
class Cols extends StatelessWidget {
  const Cols(this.children, {super.key, this.gap = 16});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: children[i])],
      ]);
}

/// Small uppercase muted caption (`text-xs uppercase tracking-wide text-fg-muted`).
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.letterSpacing = .6});
  final String text;
  final double letterSpacing;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: letterSpacing, color: context.c.fgMuted, fontWeight: FontWeight.w500));
}

// ---------------------------------------------------------------- badges

/// `rounded-md px-2 py-0.5 text-xs font-semibold` coloured badge, optional leading dot.
class ToneBadge extends StatelessWidget {
  const ToneBadge(this.label, {super.key, required this.tone, this.dot = false});
  final String label;
  final Tone tone;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.fg)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- table (table-base with row tint / opacity)

class BizRow {
  const BizRow(this.cells, {this.color, this.opacity = 1, this.onTap});
  final List<Widget> cells;
  final Color? color;
  final double opacity;
  final VoidCallback? onTap;
}

/// Card-wrapped table like the Blade `card overflow-x-auto` + `table w-full text-sm` blocks.
class BizTable extends StatelessWidget {
  const BizTable({super.key, required this.columns, required this.rows, required this.empty, this.minWidth = 860});
  final List<DataCol> columns;
  final List<BizRow> rows;
  final String empty;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget cell(Widget w, DataCol col) => Expanded(
          flex: col.flex,
          child: Align(
            alignment: col.align == TextAlign.right ? Alignment.centerRight : col.align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
            child: w,
          ),
        );
    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        child: Row(children: [
          for (final col in columns)
            cell(Text(col.label.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w500, color: c.fgMuted)), col),
        ]),
      ),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48), child: Center(child: Text(empty, style: TextStyle(color: c.fgMuted, fontSize: 14))))
      else
        for (var i = 0; i < rows.length; i++)
          _BizHoverRow(
            last: i == rows.length - 1,
            row: rows[i],
            child: Row(children: [for (var k = 0; k < columns.length; k++) cell(k < rows[i].cells.length ? rows[i].cells[k] : const SizedBox(), columns[k])]),
          ),
    ]);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusCard),
        child: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth >= minWidth) return table;
          return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: table));
        }),
      ),
    );
  }
}

class _BizHoverRow extends StatefulWidget {
  const _BizHoverRow({required this.child, required this.last, required this.row});
  final Widget child;
  final bool last;
  final BizRow row;
  @override
  State<_BizHoverRow> createState() => _BizHoverRowState();
}

class _BizHoverRowState extends State<_BizHoverRow> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final onTap = widget.row.onTap;
    Color? bg = widget.row.color;
    if (hover) bg = Color.alphaBlend(c.bg.withValues(alpha: .6), bg ?? c.surface);
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: bg, border: widget.last ? null : Border(bottom: BorderSide(color: c.border))),
          child: Opacity(
            opacity: widget.row.opacity,
            child: DefaultTextStyle.merge(style: TextStyle(fontSize: 14, color: c.fg), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Muted table cell text (`text-fg-muted`).
class CellText extends StatelessWidget {
  const CellText(this.text, {super.key, this.muted = true, this.weight, this.maxLines = 1});
  final String text;
  final bool muted;
  final FontWeight? weight;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Text(text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, color: muted ? context.c.fgMuted : context.c.fg, fontWeight: weight));
}

/// Name + email stack with an initials avatar (staff / customers first column).
class PersonCell extends StatelessWidget {
  const PersonCell({super.key, required this.name, required this.sub, required this.index});
  final String name, sub;
  final int index;
  @override
  Widget build(BuildContext context) => Row(children: [
        InitialsAvatar(name: name, index: index),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(fontSize: 12, color: context.c.fgMuted), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);
}

/// Row action icon (edit/delete/view): 32px, hover accent-soft (or danger-soft).
class RowAction extends StatefulWidget {
  const RowAction(this.icon, {super.key, required this.onTap, this.danger = false, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  final String? tooltip;
  @override
  State<RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<RowAction> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = hover ? (widget.danger ? c.danger : c.accent) : c.fgMuted;
    final bg = hover ? (widget.danger ? c.dangerSoft : c.accentSoft) : Colors.transparent;
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(widget.icon, size: 16, color: fg),
        ),
      ),
    );
    return widget.tooltip == null ? btn : Tooltip(message: widget.tooltip!, child: btn);
  }
}

class RowActions extends StatelessWidget {
  const RowActions(this.children, {super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 6), children[i]],
      ]);
}

/// Small bordered square button (pagination chevrons, stock ±).
class SquareBtn extends StatelessWidget {
  const SquareBtn(this.icon, {super.key, required this.onTap, this.size = 32, this.iconSize = 16, this.disabledOpacity = .4, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final double size, iconSize, disabledOpacity;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = Opacity(
      opacity: onTap == null ? disabledOpacity : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size <= 24 ? 6 : 8),
          hoverColor: c.accent.withValues(alpha: .06),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(size <= 24 ? 6 : 8)),
            child: Icon(icon, size: iconSize, color: c.fgMuted),
          ),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

// ---------------------------------------------------------------- form fields

/// `label` with an optional muted suffix, e.g. "Password (leave blank to keep)".
class BizLabel extends StatelessWidget {
  const BizLabel(this.text, {super.key, this.hint});
  final String text;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.c.fg)),
          if (hint != null) TextSpan(text: ' $hint', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: context.c.fgMuted)),
        ])),
      );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});
  final String? text;
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 4), child: Text(text!, style: TextStyle(fontSize: 12, color: context.c.danger)));
}

/// Text input with label (+hint suffix) and error line.
class BizField extends StatelessWidget {
  const BizField({
    super.key,
    this.label,
    this.labelHint,
    required this.controller,
    this.hint,
    this.error,
    this.obscure = false,
    this.number = false,
    this.maxLines = 1,
    this.onSubmitted,
    this.autofillHints,
  });
  final String? label, labelHint, hint, error;
  final TextEditingController controller;
  final bool obscure, number;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (label != null) BizLabel(label!, hint: labelHint),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: maxLines,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
        ErrorText(error),
      ]);
}

/// `<input type="date">` — text input (YYYY-MM-DD) with a calendar picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.controller, this.label, this.labelHint, this.onChanged});
  final TextEditingController controller;
  final String? label, labelHint;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    Future<void> pick() async {
      final cur = DateTime.tryParse(controller.text.trim());
      final d = await showDatePicker(
        context: context,
        initialDate: cur ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (d == null) return;
      controller.text = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      onChanged?.call();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) BizLabel(label!, hint: labelHint),
      TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          hintText: 'yyyy-mm-dd',
          suffixIcon: IconButton(icon: Icon(LucideIcons.calendar, size: 16, color: context.c.fgMuted), onPressed: pick),
        ),
      ),
    ]);
  }
}

/// Labelled select for forms (full width).
class BizSelect<T> extends StatelessWidget {
  const BizSelect({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        BizLabel(label),
        AppSelect<T>(value: value, items: items, onChanged: onChanged, width: double.infinity),
      ]);
}

/// Modal footer: `flex justify-end gap-3 pt-2` — Cancel (ghost) + submit (primary, disabled while saving).
class ModalActions extends StatelessWidget {
  const ModalActions({super.key, required this.submitLabel, required this.onSubmit, this.saving = false, this.onCancel});
  final String submitLabel;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final bool saving;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', kind: BtnKind.ghost, onPressed: onCancel ?? () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Btn(submitLabel, onPressed: saving ? null : onSubmit),
        ]),
      );
}

/// Checkbox with an inline label (`flex items-center gap-2 text-sm`).
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Row(children: [
          SizedBox(width: 20, height: 20, child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 14))),
        ]),
      );
}

/// Soft panel tile (`rounded-lg bg-bg px-3 py-2`): small muted label + display value.
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.label, required this.value, this.center = false, this.valueSize = 16});
  final String label, value;
  final bool center;
  final double valueSize;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: center ? 12 : 8),
        decoration: BoxDecoration(color: context.c.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.c.fgMuted)),
          const SizedBox(height: 2),
          Text(value, style: display(context, size: valueSize), overflow: TextOverflow.ellipsis),
        ]),
      );
}
