import 'package:flutter/material.dart';

import 'formations.dart';
import 'models.dart';
import 'player_widgets.dart';
import 'theme.dart';

/// The pitch with the 11 places of a formation.
class Pitch extends StatelessWidget {
  final Formation formation;
  final Map<int, Player> slots;

  /// null = read-only pitch.
  final ValueChanged<int>? onTap;

  /// Optional small text under a player's name (e.g. his rating), by slot.
  final Map<int, String> tags;

  const Pitch({
    super.key,
    required this.formation,
    required this.slots,
    this.onTap,
    this.tags = const {},
  });

  static const double _slotW = 66;
  static const double _slotH = 80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Never taller than ~75% of the screen, so the whole pitch is visible on
      // wide browser windows too; the width follows the height.
      final screenH = MediaQuery.of(context).size.height;
      final h = (c.maxWidth * 1.3).clamp(0.0, (screenH * 0.75).clamp(380.0, 640.0));
      final w = (h / 1.3).clamp(0.0, c.maxWidth);
      final slotW = (w * 0.19).clamp(52.0, _slotW);
      return Center(
          child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
              for (var i = 0; i < 11; i++)
                Positioned(
                  left: formation.slots[i].x * w - slotW / 2,
                  top: formation.slots[i].y * h - _slotH / 2,
                  width: slotW,
                  height: _slotH,
                  child: _PitchSlot(
                    position: formation.slots[i].position,
                    player: slots[i],
                    tag: tags[i],
                    onTap: onTap == null ? null : () => onTap!(i),
                  ),
                ),
            ],
          ),
        ),
      ));
    });
  }
}

class _PitchSlot extends StatelessWidget {
  final String position;
  final Player? player;
  final String? tag;
  final VoidCallback? onTap;

  const _PitchSlot({
    required this.position,
    required this.player,
    required this.onTap,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    final offPosition = p != null && !fitsSlot(p, position);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (p == null)
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(60),
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: Colors.white70, size: 20),
                )
              else
                OvrBadge(overall: p.overall, size: 42),
              if (offPosition)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9A3D),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('!',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.ink)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(110),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p?.shortName ?? position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          if (tag != null)

            Text(tag!,

                style: const TextStyle(

                    fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFFD166))),

        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1C6B3C), Color(0xFF165A32)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, grass);

    // Mowing stripes.
    final stripe = Paint()..color = Colors.white.withAlpha(8);
    const stripes = 8;
    for (var i = 0; i < stripes; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * size.height / stripes, size.width, size.height / stripes),
        stripe,
      );
    }

    final line = Paint()
      ..color = Colors.white.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const m = 10.0;
    final field = Rect.fromLTWH(m, m, size.width - 2 * m, size.height - 2 * m);
    canvas.drawRect(field, line);
    canvas.drawLine(Offset(m, size.height / 2), Offset(size.width - m, size.height / 2), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.14, line);

    final boxW = size.width * 0.5;
    final boxH = size.height * 0.14;
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, m, boxW, boxH), line);
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, size.height - m - boxH, boxW, boxH), line);
    final smallW = size.width * 0.26;
    final smallH = size.height * 0.06;
    canvas.drawRect(
        Rect.fromLTWH((size.width - smallW) / 2, m, smallW, smallH), line);
    canvas.drawRect(
        Rect.fromLTWH((size.width - smallW) / 2, size.height - m - smallH, smallW, smallH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
