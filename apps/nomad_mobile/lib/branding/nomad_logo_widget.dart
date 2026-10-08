import 'package:flutter/material.dart';
import 'nomad_brand.dart';

/// Renders the authoritative Nomad logo preserving aspect ratio and visual character.
class NomadLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showBorder;

  const NomadLogo({
    super.key,
    this.size = 48.0,
    this.borderRadius,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(
                color: Theme.of(context).dividerColor.withAlpha(40),
                width: 1.0,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          NomadBrand.logoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: NomadBrand.productName,
          errorBuilder: (context, error, stackTrace) {
            // Fallback gracefully if asset is loading or missing in tests
            return Container(
              width: size,
              height: size,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.code_rounded,
                size: size * 0.6,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            );
          },
        ),
      ),
    );
  }
}
