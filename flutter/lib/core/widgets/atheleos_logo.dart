import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Official Atheleos Metallic Gold Logo Painter.
/// Reconstructs the authentic 3-piece geometric athletic blade "A" logo
/// with mathematical precision matching the official brand assets.
class AtheleosLogoPainter extends CustomPainter {
  final Color? color;
  final bool useGradient;

  const AtheleosLogoPainter({
    this.color,
    this.useGradient = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (useGradient) {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8C86A), // Bright Metallic Gold
          Color(0xFFC59E3F), // Mid Athletic Gold
          Color(0xFFA27B26), // Deep Bronze Gold
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      paint.color = color ?? AppTheme.primaryColor;
    }

    // Piece 0: Left Wing & Top Apex
    final path0 = Path()
      ..moveTo(size.width * 0.7211, size.height * 0.0000)
      ..lineTo(size.width * 0.0000, size.height * 1.0000)
      ..lineTo(size.width * 0.3853, size.height * 0.7106)
      ..lineTo(size.width * 0.3266, size.height * 0.7106)
      ..lineTo(size.width * 0.6202, size.height * 0.2987)
      ..lineTo(size.width * 0.6202, size.height * 0.4453)
      ..lineTo(size.width * 0.7211, size.height * 0.3488)
      ..close();
    canvas.drawPath(path0, paint);

    // Piece 1: Dynamic Blade Slash
    final path1 = Path()
      ..moveTo(size.width * 1.0000, size.height * 0.2950)
      ..lineTo(size.width * 0.7358, size.height * 0.4323)
      ..lineTo(size.width * 0.7174, size.height * 0.4156)
      ..lineTo(size.width * 0.1578, size.height * 1.0000)
      ..lineTo(size.width * 0.4294, size.height * 0.8794)
      ..close();
    canvas.drawPath(path1, paint);

    // Piece 2: Right Vertical Pillar
    final path2 = Path()
      ..moveTo(size.width * 0.7211, size.height * 0.6512)
      ..lineTo(size.width * 0.6202, size.height * 0.7532)
      ..lineTo(size.width * 0.6202, size.height * 1.0000)
      ..lineTo(size.width * 0.7211, size.height * 1.0000)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant AtheleosLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.useGradient != useGradient;
  }
}

/// A standalone icon widget for the Atheleos Logo Mark.
class AtheleosLogoIcon extends StatelessWidget {
  final double size;
  final bool useGradient;
  final Color? color;

  const AtheleosLogoIcon({
    super.key,
    this.size = 32,
    this.useGradient = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: AtheleosLogoPainter(
        useGradient: useGradient,
        color: color,
      ),
    );
  }
}

/// Official Horizontal Atheleos Brand Lockup:
/// [Logo Icon]  ATHELEOS
///              TRAIN. CONNECT. INSPIRE.
class AtheleosBrandLockup extends StatelessWidget {
  final double iconSize;
  final bool showTagline;

  const AtheleosBrandLockup({
    super.key,
    this.iconSize = 36,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = iconSize * 0.7;
    final taglineSize = iconSize * 0.22;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AtheleosLogoIcon(size: iconSize),
        SizedBox(width: iconSize * 0.35),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATHELEOS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.white,
                height: 1.0,
              ),
            ),
            if (showTagline) ...[
              SizedBox(height: iconSize * 0.1),
              Text(
                'TRAIN. CONNECT. INSPIRE.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: taglineSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.2,
                  color: const Color(0xFFC59E3F),
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
