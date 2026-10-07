import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 42,
    this.borderRadius = 12,
    this.backgroundColor = Colors.white,
    this.shadows = _defaultShadows,
    this.imageAsset = 'assets/images/logo.webp',
    this.iconScale = 0.7,
    this.imageFit = BoxFit.contain,
  });

  static const List<BoxShadow> _defaultShadows = [
    BoxShadow(
      color: Color(0x1F0F0A36),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  final double size;
  final double borderRadius;
  final Color backgroundColor;
  final List<BoxShadow>? shadows;
  final String imageAsset;
  final double iconScale;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: Center(
        child: SizedBox(
          width: size * iconScale,
          height: size * iconScale,
          child: Image.asset(
            imageAsset,
            fit: imageFit,
            semanticLabel: 'logo',
          ),
        ),
      ),
    );
  }
}