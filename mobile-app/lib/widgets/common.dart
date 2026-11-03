import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// Go4Foodie logo (full colour). On dark backgrounds the wordmark switches to
/// the light variant, like the admin sidebar. `stacked` shows the icon above
/// the wordmark; otherwise the horizontal lockup is used.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 56, this.forceLight = false, this.stacked = false});
  final double height;
  final bool forceLight;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final dark = forceLight || Theme.of(context).brightness == Brightness.dark;
    final name = stacked ? 'go4foodie_logo' : 'go4foodie_logo_wide';
    return Image.asset(
      'assets/images/$name${dark ? '_light' : ''}.png',
      // The horizontal lockup is ~3.5:1, so scale it to keep the old footprint.
      height: stacked ? height : height * 0.6,
    );
  }
}

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.width = 48});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 2,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.goldBrand),
      );
}

/// Small uppercase eyebrow label, as used across the website.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 2.2,
          fontWeight: FontWeight.w700,
          color: color ?? context.c.accent,
        ),
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: borderColor ?? c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 24, 12, 10)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Text(title, style: display(context, size: 20))),
            if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

/// Coloured pill for statuses (orders, tables, bookings, stock…).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static Color colorFor(BuildContext context, String s) {
    final c = context.c;
    switch (s) {
      case 'COMPLETED':
      case 'AVAILABLE':
      case 'CONFIRMED':
      case 'ACTIVE':
      case 'PAID':
      case 'ON_DUTY':
      case 'IN_STOCK':
      case 'CLOSED':
        return c.success;
      case 'READY':
      case 'CLEANING':
      case 'SEATED':
      case 'REDEEMED':
        return c.info;
      case 'PREPARING':
      case 'RESERVED':
      case 'REQUESTED':
      case 'ON_BREAK':
      case 'LOW':
      case 'PENDING_PAYMENT':
        return c.warn;
      case 'PENDING':
      case 'WAITING_PAYMENT':
      case 'OPEN':
        return c.accent;
      case 'CANCELED':
      case 'CANCELLED':
      case 'OCCUPIED':
      case 'NO_SHOW':
      case 'ABSENT':
      case 'OUT':
      case 'FAILED':
      case 'EXPIRED':
        return c.danger;
      default:
        return c.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label ?? humanize(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: context.c.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: context.c.accent),
            ),
            const SizedBox(height: 18),
            Text(title, style: display(context, size: 20), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: TextStyle(color: context.c.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: error is ApiException ? (error as ApiException).message : '$error',
        action: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Renders an AsyncValue with consistent loading / error / data states and
/// pull-to-refresh.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, required this.onRefresh});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (d) => RefreshIndicator(onRefresh: onRefresh, color: context.c.accent, child: builder(d)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(e, onRetry: onRefresh),
    );
  }
}

class NetImage extends ConsumerWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.radius = 14, this.fit = BoxFit.cover});
  final String url;
  final double? width, height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.read(apiProvider).image(url);
    final placeholder = Container(
      width: width,
      height: height,
      color: context.c.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant_rounded, color: context.c.muted.withValues(alpha: 0.5)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: resolved.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: resolved,
              width: width,
              height: height,
              fit: fit,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, this.icon, this.delta, this.highlight = false});
  final String label;
  final String value;
  final IconData? icon;
  final num? delta;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = highlight ? AppColors.ink : c.fg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: highlight
            ? const LinearGradient(colors: [AppColors.goldSoft, AppColors.goldBrand], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: highlight ? null : c.surface,
        border: highlight ? null : Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (icon != null) Icon(icon, size: 18, color: highlight ? AppColors.ink : c.accent),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: highlight ? AppColors.ink.withValues(alpha: 0.75) : c.muted, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: display(context, size: 24, color: fg)),
        ),
        if (delta != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(delta! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16, color: highlight ? AppColors.ink : (delta! >= 0 ? c.success : c.danger)),
            const SizedBox(width: 4),
            Text('${delta! >= 0 ? '+' : ''}${delta!.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: highlight ? AppColors.ink : (delta! >= 0 ? c.success : c.danger))),
          ]),
        ],
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 44});
  final String initials;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.goldSoft, AppColors.goldDeep]),
        ),
        child: Text(initials, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
      );
}

/// Row with a label on the left and a value on the right (bills, details).
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: bold ? context.c.fg : context.c.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 14, color: valueColor)),
        ]),
      );
}

/// Open a page of the public website (privacy, terms, delete-account) in an in-app browser tab.
Future<void> openSitePage(BuildContext context, String path) async {
  final ok = await launchUrl(Uri.parse('$kSiteOrigin$path'), mode: LaunchMode.inAppBrowserView);
  if (!ok && context.mounted) toast(context, 'Could not open $kSiteOrigin$path', error: true);
}

/// "Privacy Policy · Terms" footer for the sign-in / sign-up screens.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.prefix});
  final String? prefix;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: context.c.muted, fontSize: 12.5);
    Widget link(String label, String path, [Key? key]) => TextButton(
          key: key,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32), textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          onPressed: () => openSitePage(context, path),
          child: Text(label),
        );
    return Column(children: [
      if (prefix != null) Text(prefix!, textAlign: TextAlign.center, style: style),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        link('Privacy Policy', '/privacy', const Key('login-privacy')),
        Text('·', style: style),
        link('Terms', '/terms'),
      ]),
    ]);
  }
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? context.c.danger : null,
    ));
}

/// Run an async action with a toast on failure; returns true on success.
Future<bool> guard(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, e is ApiException ? e.message : '$e', error: true);
    return false;
  }
}

Future<bool> confirm(BuildContext context, {required String title, String? message, String confirmLabel = 'Confirm', bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: display(ctx, size: 20)),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.c.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
