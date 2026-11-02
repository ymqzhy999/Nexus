import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class NexusBackground extends StatelessWidget {
  final Widget child;

  const NexusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NColors.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
          Positioned(
            top: -160,
            right: -120,
            child: _Glow(color: NColors.cyan, size: 380, opacity: 0.16),
          ),
          Positioned(
            top: 220,
            left: -180,
            child: _Glow(color: NColors.violet, size: 420, opacity: 0.12),
          ),
          Positioned(
            bottom: -220,
            right: -100,
            child: _Glow(color: NColors.pink, size: 360, opacity: 0.07),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028)
      ..strokeWidth = 0.6;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color accent;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.accent = NColors.cyan,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.055), Colors.white.withValues(alpha: 0.045)),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: card);
  }
}

class MonoLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double size;

  const MonoLabel(this.text, {super.key, this.color = NColors.muted, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: size,
        letterSpacing: 1.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.kicker, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  MonoLabel(kicker!, color: NColors.cyan),
                  const SizedBox(height: 5),
                ],
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NeonChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  const NeonChip({
    super.key,
    required this.label,
    this.color = NColors.cyan,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 9.5 : 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class ValueRing extends StatelessWidget {
  final int score;
  final double size;

  const ValueRing({super.key, required this.score, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? NColors.lime
        : score >= 70
            ? NColors.cyan
            : score >= 50
                ? NColors.amber
                : NColors.muted;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(progress: (score.clamp(0, 100)) / 100, color: color),
          ),
          Text(
            score > 0 ? '$score' : '—',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: size * 0.29,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(rect.center, rect.width / 2, bg);
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.25), color],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1).toDouble(), false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = NColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: kMono.copyWith(fontSize: 9, letterSpacing: 1.1)),
      ],
    );
  }
}

class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.color = NColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.72)]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 20,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: const Color(0xFF001318)),
              if (loading || icon != null) const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF001318),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                NColors.cyan.withValues(alpha: 0.16),
                NColors.cyan.withValues(alpha: 0.02),
              ]),
              border: Border.all(color: NColors.cyan.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: NColors.cyan, size: 30),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ScoreBar extends StatelessWidget {
  final int score;
  final Color color;

  const ScoreBar({super.key, required this.score, this.color = NColors.cyan});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 3,
        color: Colors.white.withValues(alpha: 0.06),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (score.clamp(0, 100)) / 100,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.4)]))),
        ),
      ),
    );
  }
}
