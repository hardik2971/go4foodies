import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design tokens from the Laravel admin's resources/css/app.css (light + `html.dark`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.fg,
    required this.fgMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.gold,
    required this.brandGreen,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warn,
    required this.warnSoft,
    required this.info,
    required this.infoSoft,
    required this.cardShadow,
    required this.popShadow,
  });

  final Color bg, surface, surface2, border, fg, fgMuted;
  final Color accent, accentSoft, accentDeep, gold, brandGreen;
  final Color success, successSoft, danger, dangerSoft, warn, warnSoft, info, infoSoft;
  final List<BoxShadow> cardShadow, popShadow;

  static const light = AppColors(
    bg: Color(0xFFF2F6F4),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F9F7),
    border: Color(0xFFDCE7E2),
    fg: Color(0xFF0D1F1A),
    fgMuted: Color(0xFF6A7F78),
    accent: Color(0xFFE8640F),
    accentSoft: Color(0xFFFDEDDF),
    accentDeep: Color(0xFFC24C0A),
    gold: Color(0xFFF5761E),
    brandGreen: Color(0xFF0B5E46),
    success: Color(0xFF2E9E57),
    successSoft: Color(0xFFE6F4EA),
    danger: Color(0xFFD9483F),
    dangerSoft: Color(0xFFFBE9E6),
    warn: Color(0xFFCF8A1E),
    warnSoft: Color(0xFFF9EFD9),
    info: Color(0xFF3B7FE4),
    infoSoft: Color(0xFFE8F0FE),
    cardShadow: [
      BoxShadow(color: Color(0x0F101828), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    ],
    popShadow: [BoxShadow(color: Color(0x2E101828), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -12)],
  );

  static const dark = AppColors(
    bg: Color(0xFF0A1C18),
    surface: Color(0xFF0F2621),
    surface2: Color(0xFF15312A),
    border: Color(0xFF1F3F36),
    fg: Color(0xFFF3F7F4),
    fgMuted: Color(0xFF94A9A1),
    accent: Color(0xFFF5761E),
    accentSoft: Color(0xFF3A2416),
    accentDeep: Color(0xFFFFB067),
    gold: Color(0xFFF5761E),
    brandGreen: Color(0xFF2FA57E),
    success: Color(0xFF4FBD7C),
    successSoft: Color(0xFF16311F),
    danger: Color(0xFFF0766B),
    dangerSoft: Color(0xFF3A1D1A),
    warn: Color(0xFFE6A93F),
    warnSoft: Color(0xFF362A13),
    info: Color(0xFF6AA5F5),
    infoSoft: Color(0xFF1B2740),
    cardShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    popShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 16), spreadRadius: -12)],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// Fraunces (display: headings, KPI numbers) + Manrope (body).
TextStyle display(BuildContext context, {double size = 20, FontWeight weight = FontWeight.w600, Color? color}) =>
    GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color ?? context.c.fg, height: 1.2);

const radiusCard = 16.0;

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  final text = GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: c.fg, displayColor: c.fg);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: b).copyWith(
      primary: c.accent,
      onPrimary: Colors.white,
      surface: c.surface,
      onSurface: c.fg,
      error: c.danger,
    ),
    textTheme: text,
    dividerColor: c.border,
    extensions: [c],
    textSelectionTheme: TextSelectionThemeData(selectionColor: c.accent.withValues(alpha: .35), cursorColor: c.accent),
    tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: c.fg, borderRadius: BorderRadius.circular(6)), textStyle: TextStyle(color: c.bg, fontSize: 12)),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.fgMuted, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.danger)),
    ),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : null)),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.success : c.border),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// Theme mode persisted like localStorage['admin-theme'] = 'dark' | 'light'.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  static const _key = 'admin-theme';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode = p.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  bool get isDark => mode == ThemeMode.dark;

  Future<void> toggle() async {
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString(_key, isDark ? 'dark' : 'light');
    } catch (_) {}
  }
}
