part of '../main.dart';

// A faceted molar shared by the compact wordmark and the sign-in illustration.
class _MolarMark extends CustomPainter {
  const _MolarMark({this.detailed = false});
  final bool detailed;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    const points = [
      Offset(12, 26),
      Offset(22, 13),
      Offset(37, 10),
      Offset(51, 16),
      Offset(67, 10),
      Offset(81, 15),
      Offset(89, 30),
      Offset(84, 47),
      Offset(76, 59),
      Offset(71, 81),
      Offset(63, 91),
      Offset(58, 88),
      Offset(53, 65),
      Offset(48, 59),
      Offset(42, 69),
      Offset(37, 88),
      Offset(31, 90),
      Offset(25, 78),
      Offset(21, 57),
      Offset(13, 44),
    ];
    final outline = Path()..addPolygon(points, true);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = detailed ? .85 : 5
      ..color = aquaGlow;
    if (detailed) {
      final back = outline.shift(const Offset(4, -3));
      canvas.drawPath(back, edge..color = violet);
      for (final index in [0, 2, 4, 6, 8, 10, 13, 16, 18]) {
        canvas.drawLine(
          points[index],
          points[index] + const Offset(4, -3),
          edge,
        );
      }
    }
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C585E), Color(0xFF17283B), Color(0xFF3D2C61)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawPath(outline, edge..color = aquaGlow);
    final facets = detailed
        ? [
            [0, 3, 6],
            [0, 19, 3],
            [19, 13, 3],
            [3, 7, 13],
            [7, 10, 13],
            [19, 16, 13],
            [0, 2, 3],
            [3, 4, 6],
          ]
        : [
            [0, 3, 6],
          ];
    for (final indices in facets) {
      canvas.drawPath(
        Path()..addPolygon(indices.map((i) => points[i]).toList(), false),
        edge..color = detailed ? const Color(0xAA73CEE0) : aquaGlow,
      );
    }
  }

  @override
  bool shouldRepaint(_MolarMark oldDelegate) =>
      detailed != oldDelegate.detailed;
}

class _HeaderTraces extends CustomPainter {
  const _HeaderTraces();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final x = size.width * .46;
    for (var i = 0; i < 5; i++) {
      final y = size.height - 3.0 - i * 5;
      pen.color = i == 0 ? const Color(0x665AD6EA) : const Color(0x334D7699);
      canvas.drawPath(
        Path()
          ..moveTo(x + i * 8, y)
          ..relativeLineTo(38, 0)
          ..relativeLineTo(20, -20)
          ..relativeLineTo(size.width, 0),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_HeaderTraces oldDelegate) => false;
}
