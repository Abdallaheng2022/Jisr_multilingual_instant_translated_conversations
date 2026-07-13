import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// شعار جسر — رمز تقاطع خطين داخل مربع متدرّج
class JisrLogo extends StatelessWidget {
  final double size;
  const JisrLogo({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2530), Color(0xFF0E1116)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: CustomPaint(painter: _JisrLogoPainter()),
    );
  }
}

/// يرسم لوجو جسر: قوس جسر + دعامتان + نقطة اتصال مضيئة
class _JisrLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // تدرّج التركوازي للجسر
    final tealShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5EC8C4), Color(0xFF3A8F8C)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    // تدرّج الأمبر للنقطة
    final amberShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF2A65A), Color(0xFFE0863A)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    // إحداثيات نسبية (نسبة لحجم اللوجو)
    final cx = w * 0.5;
    final archY = h * 0.62; // ارتفاع سطح الجسر
    final dotY = h * 0.40; // ارتفاع النقطة

    // 1) قوس الجسر
    final archPaint = Paint()
      ..shader = tealShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.058
      ..strokeCap = StrokeCap.round;
    final arch = Path()
      ..moveTo(w * 0.32, archY)
      ..quadraticBezierTo(cx, h * 0.36, w * 0.68, archY);
    canvas.drawPath(arch, archPaint);

    // 2) سطح الجسر
    final deckPaint = Paint()
      ..shader = tealShader
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.31, archY - h * 0.025, w * 0.38, h * 0.033),
        Radius.circular(w * 0.02),
      ),
      deckPaint,
    );

    // 3) دعامتان خفيفتان
    final pillarPaint = Paint()
      ..shader = tealShader
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5EC8C4).withOpacity(0.5);
    for (final px in [w * 0.385, w * 0.59]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, archY - h * 0.02, w * 0.023, h * 0.16),
          Radius.circular(w * 0.012),
        ),
        pillarPaint..color = const Color(0xFF3A8F8C).withOpacity(0.55),
      );
    }

    // 4) حلقات التوهّج حول النقطة
    final ring2 = Paint()
      ..color = const Color(0xFFF2A65A).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;
    canvas.drawCircle(Offset(cx, dotY), w * 0.135, ring2);

    final ring1 = Paint()
      ..color = const Color(0xFFF2A65A).withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012;
    canvas.drawCircle(Offset(cx, dotY), w * 0.10, ring1);

    // 5) نقطة الاتصال المضيئة
    final dotPaint = Paint()..shader = amberShader;
    canvas.drawCircle(Offset(cx, dotY), w * 0.066, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شارة حالة الاتصال (نقطة + نص)
class StatusPill extends StatelessWidget {
  final bool connected;
  final String label;
  const StatusPill({super.key, required this.connected, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.teal : AppColors.faint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              color: connected ? AppColors.ok : AppColors.faint,
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

/// شريط اختيار اللغتين مع زر التبديل
class LanguageBar extends StatelessWidget {
  final Language source;
  final Language target;
  final VoidCallback onSwap;
  final VoidCallback onTapSource;
  final VoidCallback onTapTarget;

  const LanguageBar({
    super.key,
    required this.source,
    required this.target,
    required this.onSwap,
    required this.onTapSource,
    required this.onTapTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        _langChip(source, active: true, onTap: onTapSource),
        GestureDetector(
          onTap: onSwap,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
                gradient: AppColors.amberGradient, shape: BoxShape.circle),
            child: const Icon(Icons.swap_horiz_rounded,
                color: AppColors.bg, size: 20),
          ),
        ),
        _langChip(target, active: false, onTap: onTapTarget),
      ]),
    );
  }

  Widget _langChip(Language l,
      {required bool active, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.tealSoft(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(children: [
            Text(l.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(l.native,
                style: TextStyle(
                    color: active ? AppColors.text : AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/// موجة صوتية متحركة (أشرطة تنبض)
class Waveform extends StatefulWidget {
  final Color color;
  final bool active;
  final double height;
  const Waveform(
      {super.key,
      this.color = AppColors.amber,
      this.active = true,
      this.height = 16});

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _bars = 4;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_bars, (i) {
          final phase = (_c.value * 2 * math.pi) + i;
          final h = widget.active
              ? (0.4 + 0.6 * (0.5 + 0.5 * math.sin(phase))) * widget.height
              : widget.height * 0.4;
          return Container(
            width: 2.5,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
                color: widget.color, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

/// زر ميكروفون كبير نابض
class MicButton extends StatefulWidget {
  final bool recording;
  final VoidCallback onTap;
  final double size;
  const MicButton({
    super.key,
    required this.recording,
    required this.onTap,
    this.size = 88,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size + 16,
        height: widget.size + 16,
        child: Stack(alignment: Alignment.center, children: [
          if (widget.recording)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: widget.size + 16 * _pulse.value,
                height: widget.size + 16 * _pulse.value,
                decoration: BoxDecoration(
                    color: AppColors.dangerGradient.colors.first
                        .withOpacity(0.15 * (1 - _pulse.value)),
                    shape: BoxShape.circle),
              ),
            )
          else
            Container(
              width: widget.size + 12,
              height: widget.size + 12,
              decoration: BoxDecoration(
                  color: AppColors.tealSoft(0.12), shape: BoxShape.circle),
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: widget.recording
                  ? AppColors.dangerGradient
                  : AppColors.tealGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.recording ? AppColors.danger : AppColors.teal)
                      .withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              widget.recording
                  ? Icons.stop_rounded
                  : Icons.mic_rounded,
              color: AppColors.bg,
              size: widget.size * 0.4,
            ),
          ),
        ]),
      ),
    );
  }
}

/// شريط عدّاد الرسائل المجانية
class FreeCounter extends StatelessWidget {
  final int remaining;
  final VoidCallback onUpgrade;
  final int hoursUntilReset; // ساعات حتى تجديد الرصيد اليومي
  const FreeCounter({
    super.key,
    required this.remaining,
    required this.onUpgrade,
    this.hoursUntilReset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final out = remaining <= 0;
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: out ? AppColors.danger.withOpacity(0.1) : AppColors.amberSoft(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(out ? Icons.lock_outline_rounded : Icons.card_giftcard_rounded,
              color: out ? AppColors.danger : AppColors.amber, size: 15),
          const SizedBox(width: 6),
          Text(
            out
                ? 'انتهت ترجمات اليوم — تتجدد بعد $hoursUntilReset ساعة'
                : '$remaining ترجمات مجانية اليوم',
            style: TextStyle(
                color: out ? AppColors.danger : AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }
}
