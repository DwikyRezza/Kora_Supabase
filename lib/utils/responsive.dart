import 'package:flutter/material.dart';

/// Responsive utility — wraps MediaQuery untuk skala font, padding, dan ukuran
/// berdasarkan lebar layar. Dibuat sebagai extension agar mudah dipakai di semua Widget.
///
/// Breakpoints:
///   compact  : width < 360  (HP kecil seperti iPhone SE)
///   normal   : 360 <= width < 600 (HP standar - referensi desain)
///   medium   : 600 <= width < 840 (tablet kecil / HP besar)
///   expanded : width >= 840 (tablet besar / landscape)
extension Responsive on BuildContext {
  double get _width => MediaQuery.of(this).size.width;
  double get _height => MediaQuery.of(this).size.height;

  // ── Breakpoints ──────────────────────────────────────────────────────────
  bool get isCompact  => _width < 360;
  bool get isNormal   => _width >= 360 && _width < 600;
  bool get isMedium   => _width >= 600 && _width < 840;
  bool get isExpanded => _width >= 840;
  bool get isTablet   => _width >= 600;

  // ── Scale factor (1.0 = layar 360dp) ────────────────────────────────────
  double get _scale => (_width / 360.0).clamp(0.75, 1.5);

  // ── Font sizes — scalable ────────────────────────────────────────────────
  double get fontXS   => (10 * _scale).clamp(9,  13);
  double get fontSM   => (12 * _scale).clamp(11, 15);
  double get fontBase => (14 * _scale).clamp(12, 17);
  double get fontMD   => (16 * _scale).clamp(14, 20);
  double get fontLG   => (18 * _scale).clamp(16, 22);
  double get fontXL   => (22 * _scale).clamp(18, 28);
  double get font2XL  => (26 * _scale).clamp(22, 34);
  double get font3XL  => (32 * _scale).clamp(26, 42);

  // ── Spacing ──────────────────────────────────────────────────────────────
  double get spaceXS => (4 * _scale).clamp(3, 6);
  double get spaceSM => (8 * _scale).clamp(6, 12);
  double get spaceMD => (12 * _scale).clamp(10, 16);
  double get spaceLG => (16 * _scale).clamp(12, 22);
  double get spaceXL => (24 * _scale).clamp(18, 32);
  double get space2XL => (32 * _scale).clamp(24, 44);

  // ── Padding preset ───────────────────────────────────────────────────────
  EdgeInsets get paddingH => EdgeInsets.symmetric(horizontal: spaceLG);
  EdgeInsets get paddingPage => EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceMD);

  // ── Icon sizes ───────────────────────────────────────────────────────────
  double get iconSM  => (18 * _scale).clamp(16, 24);
  double get iconMD  => (22 * _scale).clamp(18, 28);
  double get iconLG  => (28 * _scale).clamp(22, 36);

  // ── Border radius ────────────────────────────────────────────────────────
  double get radiusSM => (8 * _scale).clamp(6, 12);
  double get radiusMD => (12 * _scale).clamp(10, 16);
  double get radiusLG => (16 * _scale).clamp(12, 22);
  double get radiusXL => (24 * _scale).clamp(18, 32);

  // ── Convenient sizes ─────────────────────────────────────────────────────
  double get avatarSM => (36 * _scale).clamp(30, 48);
  double get avatarMD => (48 * _scale).clamp(40, 60);
  double get avatarLG => (80 * _scale).clamp(64, 100);
  double get buttonHeight => (52 * _scale).clamp(44, 64);

  // ── Screen dimensions ────────────────────────────────────────────────────
  double get screenWidth  => _width;
  double get screenHeight => _height;

  // ── Column count helper untuk grid ──────────────────────────────────────
  int get gridColumns => isTablet ? 3 : 2;
}

/// Responsive SizedBox helper
class RSpace extends StatelessWidget {
  final double Function(BuildContext) sizeOf;
  final bool horizontal;

  const RSpace.sm({super.key, this.horizontal = false})
      : sizeOf = _smSize;
  const RSpace.md({super.key, this.horizontal = false})
      : sizeOf = _mdSize;
  const RSpace.lg({super.key, this.horizontal = false})
      : sizeOf = _lgSize;
  const RSpace.xl({super.key, this.horizontal = false})
      : sizeOf = _xlSize;

  static double _smSize(BuildContext ctx) => ctx.spaceSM;
  static double _mdSize(BuildContext ctx) => ctx.spaceMD;
  static double _lgSize(BuildContext ctx) => ctx.spaceLG;
  static double _xlSize(BuildContext ctx) => ctx.spaceXL;

  @override
  Widget build(BuildContext context) {
    final size = sizeOf(context);
    return SizedBox(
      width:  horizontal ? size : 0,
      height: horizontal ? 0 : size,
    );
  }
}
