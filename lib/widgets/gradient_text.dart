import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Text painted with the aurora sweep. Used for the wordmark and hero numbers.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = WhatIfColors.auroraSweep,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

/// The WhatIf wordmark: "What" in aurora, "If" solid white, an intentional
/// pause between them — the brand *is* a question hanging in the air.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 40});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      height: 1.0,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        GradientText('What', style: style),
        Text('If', style: style.copyWith(color: WhatIfColors.textHigh)),
        Transform.translate(
          offset: Offset(fontSize * 0.02, -fontSize * 0.02),
          child: GradientText('?',
              style: style.copyWith(color: WhatIfColors.cyan),
              gradient: const LinearGradient(
                colors: [WhatIfColors.cyan, WhatIfColors.mint],
              )),
        ),
      ],
    );
  }
}
