import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/motion.dart';
import 'nav.dart';

/// Sidebar (72px, icon nav) + sticky topbar + content — layouts/app.blade.php.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    // The layout recomputed the attention badge on every page render.
    if (old.path != widget.path) context.read<Session>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final session = context.watch<Session>();
    final (title, subtitle) = titleFor(widget.path);
    return Title(
      title: '$title · Go4Foodie Admin',
      color: c.accent,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(path: widget.path, session: session),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Topbar(title: title, subtitle: subtitle),
                  // The router's navigator; each page brings its own scroll view (router.dart) so
                  // route transitions animate instead of the subtree being rebuilt.
                  // Own semantics container: a route's BlockSemantics barrier would otherwise hide the
              // sidebar + topbar (painted earlier in the same container) from screen readers.
              Expanded(child: Semantics(container: true, explicitChildNodes: true, child: ClipRect(child: widget.child))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.path, required this.session});
  final String path;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = context.watch<ThemeController>().isDark;
    final visible = [
      for (final n in navItems)
        if (session.can(n.perm)) n,
    ];
    final activeIndex = visible.indexWhere((n) => isActive(path, n.href));

    // Items sit on a transparent layer; one accent "pill" slides between them (_SlidingPill).
    Widget item(NavItem n, {bool ownBackground = false}) {
      final active = isActive(path, n.href);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: _NavPill.gap),
        child: Tooltip(
          message: n.label,
          preferBelow: false,
          excludeFromSemantics: true,
          child: _NavButton(
            label: n.label,
            icon: n.icon,
            active: active,
            background: ownBackground && active,
            onTap: () => context.go(n.href),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          InkWell(
            onTap: () => context.go('/dashboard'),
            child: Image.asset(
              dark
                  ? 'assets/images/go4foodie-logo-light.png'
                  : 'assets/images/go4foodie-logo.png',
              width: 64,
              height: 64,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  _NavPill(index: activeIndex),
                  Column(children: [for (final n in visible) item(n)]),
                ],
              ),
            ),
          ),
          if (session.can(auditNav.perm)) item(auditNav, ownBackground: true),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// The accent highlight behind the active sidebar item; slides (with a slight stretch) to the new item.
class _NavPill extends StatelessWidget {
  const _NavPill({required this.index});
  final int index;
  static const size = 44.0, gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shown = index >= 0;
    return AnimatedPositioned(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: kEaseOut,
      top: (shown ? index : 0) * (size + gap * 2) + gap,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: .35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar icon button: icon colour animates with the active state; hover tint + press scale.
class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.background = false,
  });
  final String label;
  final IconData icon;
  final bool active, background;
  final VoidCallback onTap;
  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = widget.active ? Colors.white : (_hover ? c.accent : c.fgMuted);
    // InkWell (not a bare GestureDetector) keeps button semantics and keyboard focus.
    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          splashColor: c.accent.withValues(alpha: .18),
          highlightColor: Colors.transparent,
          child: PressScale(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: _NavPill.size,
              height: _NavPill.size,
              decoration: BoxDecoration(
                color: widget.background
                    ? c.accent
                    : (_hover && !widget.active
                          ? c.accentSoft
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: fg),
                duration: const Duration(milliseconds: 260),
                builder: (_, color, _) => AnimatedScale(
                  scale: _hover && !widget.active ? 1.08 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(widget.icon, size: 20, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final session = context.watch<Session>();
    final theme = context.watch<ThemeController>();
    final wide = MediaQuery.of(context).size.width >= 768;
    final count = session.attentionCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: .8),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            // Title cross-fades and rises slightly when the page changes.
            child: AnimatedSwitcher(
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 340),
              switchInCurve: kEaseOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(title),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: display(context, size: 24),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: c.fgMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (wide)
            // Decorative in the original too (no page reads ?q=).
            SizedBox(
              width: 360,
              child: TextField(
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'type here to search anything',
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 16,
                    color: c.fgMuted,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⌘F',
                        style: TextStyle(fontSize: 11, color: c.fgMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          _RoundBtn(
            icon: theme.isDark ? LucideIcons.sun : LucideIcons.moon,
            tooltip: 'Toggle theme',
            onTap: theme.toggle,
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _RoundBtn(
                icon: LucideIcons.bell,
                tooltip: 'Notifications',
                onTap: () => context.go('/notifications'),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          _UserMenu(session: session),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: c.fg),
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final u = session.user;
    final wide = MediaQuery.of(context).size.width >= 640;
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 48),
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      onSelected: (v) async {
        if (v == 'settings') context.go('/settings');
        if (v == 'logout') {
          await session.logout();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u?.name ?? '',
                style: TextStyle(fontWeight: FontWeight.w600, color: c.fg),
              ),
              Text(
                u?.roleLabel ?? '',
                style: TextStyle(fontSize: 12, color: c.fgMuted),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(LucideIcons.settings, size: 16, color: c.fg),
              const SizedBox(width: 10),
              const Text('Settings'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(LucideIcons.logOut, size: 16, color: c.danger),
              const SizedBox(width: 10),
              Text('Sign out', style: TextStyle(color: c.danger)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.accentSoft,
            child: Text(
              u?.initials ?? '',
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  u?.name ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  u?.roleLabel ?? '',
                  style: TextStyle(fontSize: 11, color: c.fgMuted),
                ),
              ],
            ),
          ],
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 16, color: c.fgMuted),
        ],
      ),
    );
  }
}
