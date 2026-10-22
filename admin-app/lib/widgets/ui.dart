import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'motion.dart';
export 'motion.dart'
    show Reveal, CountUpText, PressScale, HoverLift, SkeletonPage;

/// Shared primitives — Flutter versions of the Blade components/classes (card, btn-*, pills,
/// x-status, x-biz.stat, modals, toasts, table-base).

// ---------------------------------------------------------------- card

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color, borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: c.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return Reveal(child: box);
    return Reveal(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: HoverLift(
            radius: radiusCard,
            child: PressScale(child: box),
          ),
        ),
      ),
    );
  }
}

/// Card title row: display-font heading + optional trailing widget.
class CardHeader extends StatelessWidget {
  const CardHeader(this.title, {super.key, this.trailing, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: display(context, size: 18)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: context.c.fgMuted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// ---------------------------------------------------------------- stat tile (x-biz.stat)

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: c.fgMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                CountUpText(
                  value,
                  style: display(context, size: 20, color: valueColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of equal-width tiles (stats rows, card grids).
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.minWidth = 200,
    this.spacing = 16,
    this.maxCols = 4,
  });
  final List<Widget> children;
  final double minWidth, spacing;
  final int maxCols;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = (box.maxWidth / minWidth).floor().clamp(1, maxCols);
      final w = (box.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}

// ---------------------------------------------------------------- status badge (components/status.blade.php)

enum Tone { muted, warn, info, success, danger, accent }

const statusTones = <String, Tone>{
  'PENDING': Tone.muted,
  'PREPARING': Tone.warn,
  'READY': Tone.info,
  'COMPLETED': Tone.success,
  'CANCELED': Tone.danger,
  'CANCELLED': Tone.danger,
  'REQUESTED': Tone.warn,
  'CONFIRMED': Tone.info,
  'SEATED': Tone.accent,
  'NO_SHOW': Tone.muted,
  'ON_DUTY': Tone.success,
  'ON_BREAK': Tone.warn,
  'ABSENT': Tone.danger,
  'OFF': Tone.muted,
  'ACTIVE': Tone.success,
  'INACTIVE': Tone.muted,
  'PAID': Tone.info,
  'PENDING_PAYMENT': Tone.warn,
  'REDEEMED': Tone.accent,
  'EXPIRED': Tone.muted,
  'FAILED': Tone.danger,
  'AVAILABLE': Tone.success,
  'RESERVED': Tone.warn,
  'OCCUPIED': Tone.danger,
  'WAITING_PAYMENT': Tone.accent,
  'CLEANING': Tone.info,
  'OUT_OF_SERVICE': Tone.muted,
  'OPEN': Tone.accent,
  'CLOSED': Tone.success,
};

({Color fg, Color bg}) toneColors(BuildContext context, Tone t) {
  final c = context.c;
  return switch (t) {
    Tone.muted => (fg: c.fgMuted, bg: c.bg),
    Tone.warn => (fg: c.warn, bg: c.warnSoft),
    Tone.info => (fg: c.info, bg: c.infoSoft),
    Tone.success => (fg: c.success, bg: c.successSoft),
    Tone.danger => (fg: c.danger, bg: c.dangerSoft),
    Tone.accent => (fg: c.accent, bg: c.accentSoft),
  };
}

/// "PENDING_PAYMENT" → "Pending Payment".
String titleCase(String s) => s
    .toLowerCase()
    .split('_')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label, this.dot = true});
  final String status;
  final String? label;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, statusTones[status] ?? Tone.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label ?? titleCase(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded pill (e.g. "Online", "Table 4", gateway name).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.fg, this.bg});
  final String text;
  final Color? fg, bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg ?? context.c.accentSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: fg ?? context.c.accent,
      ),
    ),
  );
}

// ---------------------------------------------------------------- filter pills

class FilterPills<T> extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? label;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: o == value ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: o == value ? c.accent : c.border),
              ),
              child: Text(
                label?.call(o) ?? '$o',
                style: TextStyle(
                  fontSize: 14,
                  color: o == value ? Colors.white : c.fgMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- buttons

enum BtnKind { primary, ghost, danger, dangerOutline }

class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.kind = BtnKind.primary,
    this.busy = false,
    this.busyLabel,
    this.expand = false,
    this.small = false,
  });
  final String label;
  final String? busyLabel;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool busy, expand, small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (c.accent, Colors.white, c.accent),
      BtnKind.ghost => (c.surface, c.fg, c.border),
      BtnKind.danger => (c.danger, Colors.white, c.danger),
      BtnKind.dangerOutline => (
        c.surface,
        c.danger,
        c.danger.withValues(alpha: .4),
      ),
    };
    final disabled = onPressed == null || busy;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 16, color: fg),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            busy ? (busyLabel ?? label) : label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: small ? 13 : 14,
            ),
          ),
        ),
      ],
    );
    return PressScale(
      enabled: !disabled,
      child: AnimatedOpacity(
        opacity: disabled ? .6 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : onPressed,
            mouseCursor: disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: small ? 12 : 16,
                vertical: small ? 7 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Square icon button (row actions: edit/delete/view, topbar).
class IconBtn extends StatelessWidget {
  const IconBtn(
    this.icon, {
    super.key,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 16,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: color ?? context.c.fgMuted),
      ),
    ),
  );
}

// ---------------------------------------------------------------- form fields

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.c.fg,
      ),
    ),
  );
}

/// Labelled text input with an optional error line underneath.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.prefixIcon,
    this.onChanged,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure, enabled;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      FieldLabel(label),
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 16, color: context.c.fgMuted),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            error!,
            style: TextStyle(fontSize: 12, color: context.c.danger),
          ),
        ),
    ],
  );
}

/// Dropdown styled like `.input` selects.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
  });
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? label;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final field = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.any((i) => i.$1 == value) ? value : null,
          isExpanded: width != null || label != null,
          isDense: false,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: c.surface,
          style: TextStyle(fontSize: 14, color: c.fg),
          icon: Icon(LucideIcons.chevronDown, size: 16, color: c.fgMuted),
          items: [
            for (final i in items)
              DropdownMenuItem(
                value: i.$1,
                child: Text(i.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null || null is T) onChanged(v as T);
          },
        ),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [FieldLabel(label!), field],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 280,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          LucideIcons.search,
          size: 16,
          color: context.c.fgMuted,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- data table (table-base)

class DataCol {
  const DataCol(this.label, {this.flex = 1, this.align = TextAlign.left});
  final String label;
  final int flex;
  final TextAlign align;
}

/// Card-wrapped table: uppercase muted header, rows with hover + optional tap, empty message.
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.empty = 'Nothing here yet.',
    this.footer,
    this.minWidth = 900,
  });
  final List<DataCol> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final String empty;
  final String? footer;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget cell(Widget w, DataCol col) => Expanded(
      flex: col.flex,
      child: Align(
        alignment: col.align == TextAlign.right
            ? Alignment.centerRight
            : col.align == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: w,
      ),
    );
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              for (final col in columns)
                cell(
                  Text(
                    col.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w600,
                      color: c.fgMuted,
                    ),
                  ),
                  col,
                ),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                empty,
                style: TextStyle(color: c.fgMuted, fontSize: 14),
              ),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            _HoverRow(
              last: i == rows.length - 1,
              onTap: onRowTap == null ? null : () => onRowTap!(i),
              child: Row(
                children: [
                  for (var k = 0; k < columns.length; k++)
                    cell(
                      k < rows[i].length ? rows[i][k] : const SizedBox(),
                      columns[k],
                    ),
                ],
              ),
            ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= minWidth) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minWidth, child: table),
              );
            },
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              footer!,
              style: TextStyle(fontSize: 12, color: c.fgMuted),
            ),
          ),
      ],
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.last, this.onTap});
  final Widget child;
  final bool last;
  final VoidCallback? onTap;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: hover ? c.bg.withValues(alpha: .6) : null,
            border: widget.last
                ? null
                : Border(bottom: BorderSide(color: c.border)),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, color: c.fg),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Secondary muted text.
class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: size, color: context.c.fgMuted),
    overflow: TextOverflow.ellipsis,
  );
}

// ---------------------------------------------------------------- modal

/// Modal dialog: black/40 overlay, max-w-lg (configurable), rounded-2xl, display-font title + X.
/// Closes on ESC, backdrop click and X (showDialog defaults).
Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  double maxWidth = 512,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .4),
    transitionDuration: const Duration(milliseconds: 280),
    // Backdrop blur + the dialog scaling up from 96% with a fade.
    transitionBuilder: (ctx, anim, _, child) {
      if (MediaQuery.of(ctx).disableAnimations) return child;
      final t = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.22, 1, 0.36, 1),
        reverseCurve: Curves.easeIn,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 3 * anim.value,
          sigmaY: 3 * anim.value,
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: .96, end: 1.0).animate(t),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (ctx, _, _) {
      final c = ctx.c;
      return Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(ctx).size.height * .9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: display(ctx, size: 20))),
                    IconBtn(
                      LucideIcons.x,
                      onPressed: () => Navigator.of(ctx).pop(),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: builder(ctx))),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// `confirm(message)` equivalent.
Future<bool> confirmDialog(
  BuildContext context,
  String message, {
  String ok = 'OK',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.c.surface,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

// ---------------------------------------------------------------- toasts (bottom-right, 3.5 s)

final toastMessenger = GlobalKey<ScaffoldMessengerState>();

void toast(String message, {bool error = false}) {
  final m = toastMessenger.currentState;
  if (m == null) return;
  final ctx = toastMessenger.currentContext!;
  final c = ctx.c;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: error ? Colors.white : c.bg, fontSize: 14),
      ),
      backgroundColor: error ? c.danger : c.fg,
      behavior: SnackBarBehavior.floating,
      width: 360,
      duration: const Duration(milliseconds: 3500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Run a mutation: shows the server error as an error toast (window.api + toast pattern). Returns success.
Future<bool> guard(Future<void> Function() fn, {String? success}) async {
  try {
    await fn();
    if (success != null) toast(success);
    return true;
  } on ApiError catch (e) {
    toast(e.message, error: true);
  } catch (e) {
    toast('$e', error: true);
  }
  return false;
}

// ---------------------------------------------------------------- page loading

/// Loads page data once (and on [reload]); shows spinner / error with retry.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Skeleton → content cross-fade (a reload keeps the same content key, so it doesn't re-fade).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(
          data != null ? 'content' : (loading ? 'loading' : 'error'),
        ),
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading && data == null) return const SkeletonPage();
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cloudOff, size: 32, color: context.c.fgMuted),
              const SizedBox(height: 12),
              Text(
                error is ApiError
                    ? (error as ApiError).message
                    : 'Could not load this page.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Btn(
                'Try again',
                kind: BtnKind.ghost,
                icon: LucideIcons.refreshCw,
                onPressed: () {
                  setState(() => loading = true);
                  _load();
                },
              ),
            ],
          ),
        ),
      );
    }
    return widget.builder(context, data as T, _load);
  }
}

/// Periodic callback while mounted (polling / clock re-render).
class Ticker {
  Ticker(Duration every, void Function() fn)
    : _t = Timer.periodic(every, (_) => fn());
  final Timer _t;
  void cancel() => _t.cancel();
}
