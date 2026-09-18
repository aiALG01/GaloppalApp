import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raw brand palette ("Naturverbunden. Strukturiert. Zielgerichtet.") —
/// greens for growth/balance/calm, blues for structure/planning/clarity.
/// [AppColors] below assigns these to semantic roles; reach for this class
/// directly only when introducing a new semantic role.
class AppPalette {
  AppPalette._();

  static const Color tiefgruen = Color(
    0xFF1F3D2E,
  ); // Stabilität, Tiefe, Vertrauen
  static const Color waldgruen = Color(
    0xFF385E46,
  ); // Natur, Wachstum, Ausgeglichenheit
  static const Color salbeigruen = Color(
    0xFFA6B79A,
  ); // Frische, Harmonie, Leichtigkeit
  static const Color tiefblau = Color(
    0xFF1D3557,
  ); // Verlässlichkeit, Klarheit, Fokus
  static const Color taubenblau = Color(
    0xFF4C6A80,
  ); // Ruhe, Struktur, Kommunikation
  static const Color lichtblau = Color(
    0xFFBFD6E6,
  ); // Weite, Offenheit, Übersicht
  static const Color sand = Color(0xFFE8E5D9);
  static const Color steingrau = Color(0xFFD7DADC);
  static const Color warmweiss = Color(0xFFFAF8F3);
}

/// Design tokens for the app UI. Semantic roles map onto [AppPalette]:
/// green (Tiefgrün) stays the primary brand color, blue (Taubenblau) marks
/// structure — recurrence, series, scheduling.
class AppColors {
  AppColors._();

  static const Color background = AppPalette.sand; // outer / auth backdrop
  static const Color surface = AppPalette.warmweiss; // app screen background
  static const Color card = Colors.white;

  static const Color ink = Color(0xFF220C10); // primary text
  static Color inkFaint(double opacity) => ink.withValues(alpha: opacity);

  static const Color green = AppPalette.tiefgruen; // primary action color
  static const Color greenDark = Color(0xFF16291F); // pressed/hover depth

  static const Color mint = AppPalette.salbeigruen; // light accent green
  static Color mintFaint(double opacity) => mint.withValues(alpha: opacity);
  static const Color mintTextStrong = AppPalette.tiefgruen;
  static const Color mintText = AppPalette.waldgruen;

  static const Color blue =
      AppPalette.taubenblau; // structure / series / recurrence accent
  static Color blueFaint(double opacity) => blue.withValues(alpha: opacity);
  static const Color blueText = AppPalette.tiefblau;

  static const Color placeholderStripeLight = AppPalette.sand;
  static const Color placeholderStripeDark = AppPalette.steingrau;
}

class AppRadius {
  AppRadius._();
  static const double sm = 9.0;
  static const double md = 12.0;
  static const double card = 16.0;
  static const double lg = 18.0;
  static const double xl = 20.0;
  static const double sheet = 26.0;
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle serif({
    double size = 20,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = -0.01,
    double? height,
  }) => GoogleFonts.playfairDisplay(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle sans({
    double size = 14,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle eyebrow({Color? color}) => sans(
    size: 10.5,
    weight: FontWeight.w600,
    letterSpacing: 1.4 / 10.5, // ~.14em
    color: color ?? AppColors.inkFaint(.45),
  );
}

List<BoxShadow> cardShadow({
  double opacity = .06,
  double blur = 12,
  double y = 2,
}) => [
  BoxShadow(
    color: AppColors.ink.withValues(alpha: opacity),
    blurRadius: blur,
    offset: Offset(0, y),
  ),
];

BoxDecoration cardDecoration({
  double radius = AppRadius.card,
  double shadowOpacity = .06,
}) => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: cardShadow(opacity: shadowOpacity),
);

/// Repeating diagonal stripe placeholder used everywhere a photo would sit
/// in the real product (rider avatars, trainer avatars, hero image).
class PlaceholderStripe extends StatelessWidget {
  const PlaceholderStripe({
    super.key,
    this.borderRadius = AppRadius.md,
    this.child,
  });

  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: _StripePainter(),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.placeholderStripeLight;
    canvas.drawRect(Offset.zero & size, paint);
    final stripePaint = Paint()..color = AppColors.placeholderStripeDark;
    const gap = 9.0;
    final diagonal = size.width + size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -diagonal; x < diagonal; x += gap * 2) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + gap, 0)
        ..lineTo(x + gap + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: AppColors.surface,
    ),
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.ink,
    ),
  );
}
