import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Rounded "chip" label (Intermediate, 15 min, Open, etc.).
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.bg = AppColors.chipNeutralBg,
    this.fg = AppColors.chipNeutralFg,
    this.dot = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool dot;

  const TagChip.blue(String label, {Key? key})
      : this(label, key: key, bg: AppColors.chipBlueBg, fg: AppColors.chipBlueFg);
  const TagChip.green(String label, {Key? key})
      : this(label, key: key, bg: AppColors.chipGreenBg, fg: AppColors.chipGreenFg);
  const TagChip.orange(String label, {Key? key})
      : this(label, key: key, bg: AppColors.chipOrangeBg, fg: AppColors.chipOrangeFg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Text('● ', style: TextStyle(color: fg, fontSize: 11, height: 1)),
          ],
          // Flexible so a long tag ellipsises instead of overflowing the row
          // it sits in — chips are often placed next to expanding content.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase tracking-spaced section heading.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Pill button filled with the indigo→cyan brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 54,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.indigo, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button on a translucent white fill — for dark backgrounds.
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// `mm:ss` pill with a timer glyph. Turns amber when [seconds] runs low.
class SessionTimer extends StatelessWidget {
  const SessionTimer({
    super.key,
    required this.seconds,
    this.lowThreshold = 15,
    this.onDark = true,
  });

  final int seconds;
  final int lowThreshold;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final low = seconds <= lowThreshold;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    final base = low
        ? AppColors.warning
        : (onDark ? Colors.white : AppColors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 15, color: base),
          const SizedBox(width: 6),
          Text(
            '$m:$s',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: base,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Four little bars that bounce while audio plays.
class AudioBarsBadge extends StatelessWidget {
  const AudioBarsBadge({
    super.key,
    required this.controller,
    this.color = AppColors.secondary,
  });

  final Animation<double> controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          final phase = (controller.value + i / 4) % 1;
          final h = 6 + 12 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi)).abs();
          return Container(
            width: 3,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}

/// Animated recording waveform.
///
/// [t] advances the travelling wave; [level] (0..1) scales the overall
/// amplitude so the bars can follow a real microphone signal.
class WaveformPainter extends CustomPainter {
  WaveformPainter(this.t, {this.level = 1.0, this.bars = 40, this.colors});

  final double t;
  final double level;
  final int bars;
  final List<Color>? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / bars;
    final mid = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final ramp = colors ?? const [AppColors.indigo, AppColors.secondary];
    final rnd = math.Random(7);
    for (int i = 0; i < bars; i++) {
      final base = rnd.nextDouble();
      final wobble = 0.5 + 0.5 * math.sin((i * 0.5) + t * 2 * math.pi);
      final amp = (size.height / 2 - 4) *
          (0.18 + 0.82 * base * wobble) *
          level.clamp(0.08, 1.0);
      final x = gap * i + gap / 2;
      paint.color = Color.lerp(ramp.first, ramp.last, i / bars)!;
      canvas.drawLine(Offset(x, mid - amp), Offset(x, mid + amp), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.t != t || old.level != level;
}

/// One horizontal meter: label (+ optional weight) · track · value.
///
/// Used by the rubric breakdown, the FLAS panel and the weakness cards.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.ratio,
    this.weight,
    this.value,
    this.barColor = AppColors.indigo,
    this.valueColor = AppColors.dark,
    this.labelWidth = 118,
    this.trackHeight = 8,
  });

  final String label;
  /// Fill fraction, 0..1.
  final double ratio;
  /// Optional "25%" suffix rendered next to the label.
  final String? weight;
  /// Optional right-hand readout, e.g. "8.0".
  final String? value;
  final Color barColor;
  final Color valueColor;
  final double labelWidth;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (weight != null)
                  TextSpan(
                    text: '  $weight',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: MeterBar(ratio: ratio, color: barColor, height: trackHeight)),
        if (value != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            // Đủ chỗ cho 3 chữ số: thang rubric là 0-100, không phải 0-10. Rộng 30 thì "87.8"
            // xuống dòng thành "87." / "8".
            width: 38,
            child: Text(
              value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bare rounded progress track — the bar inside [MeterRow], reusable alone.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.ratio,
    this.color = AppColors.indigo,
    this.height = 8,
    this.track = const Color(0xFFF1F5F9),
  });

  final double ratio;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

/// Bordered box with a big number over a small uppercase caption.
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.value,
    required this.caption,
    this.valueColor = AppColors.ink,
  });

  final String value;
  final String caption;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textGhost,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded card filled with the brand gradient — score heroes, profile heroes.
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

/// Circular outlined icon button used in the app bars.
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF444444)),
      ),
    );
  }
}
