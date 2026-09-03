import 'package:flutter/material.dart';

/// One sprite of stroke icons.
///
/// The spec bans emoji outright and asks for 1.7-1.9px stroke glyphs in
/// `currentColor`. Rather than pull in an SVG package, every glyph is a [Path]
/// drawn on a 24x24 grid and stroked by [_IconPainter]; stroke width scales
/// with the icon the way a stroke icon set does.
typedef _Draw = void Function(Path p);

@immutable
class AppIconData {
  const AppIconData(this._draw);
  final _Draw _draw;

  Path _build() {
    final p = Path();
    _draw(p);
    return p;
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 24, this.color, this.strokeWidth = 1.8});

  final AppIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IconPainter(
          path: icon._build(),
          color: resolved ?? const Color(0xFF000000),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.path, required this.color, required this.strokeWidth});

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.path != path || old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

void _line(Path p, double x1, double y1, double x2, double y2) {
  p.moveTo(x1, y1);
  p.lineTo(x2, y2);
}

void _poly(Path p, List<double> pts, {bool close = false}) {
  p.moveTo(pts[0], pts[1]);
  for (var i = 2; i < pts.length; i += 2) {
    p.lineTo(pts[i], pts[i + 1]);
  }
  if (close) p.close();
}

void _rrect(Path p, double l, double t, double w, double h, double r) {
  p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)));
}

void _circle(Path p, double cx, double cy, double r) {
  p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

/// A one-logical-unit stub, rendered as a dot by the round stroke cap.
void _dot(Path p, double x, double y) {
  p.moveTo(x, y);
  p.lineTo(x, y + 0.01);
}

abstract final class AppIcons {
  // -- Navigation -----------------------------------------------------------
  static final home = AppIconData((p) {
    _poly(p, [3, 10.4, 12, 3.2, 21, 10.4, 21, 20.3, 3, 20.3], close: true);
    _poly(p, [9.4, 20.3, 9.4, 14.2, 14.6, 14.2, 14.6, 20.3]);
  });

  static final book = AppIconData((p) {
    _rrect(p, 3.5, 3, 17, 18, 2.2);
    _line(p, 8.2, 3, 8.2, 21);
    _line(p, 11.6, 8.6, 17.2, 8.6);
    _line(p, 11.6, 12.6, 17.2, 12.6);
  });

  static final clock = AppIconData((p) {
    _circle(p, 12, 12, 8.6);
    _poly(p, [12, 7.2, 12, 12.2, 15.6, 14.3]);
  });

  static final person = AppIconData((p) {
    _circle(p, 12, 8.4, 3.8);
    p.moveTo(4.6, 20.4);
    p.cubicTo(4.6, 16.6, 7.9, 14.4, 12, 14.4);
    p.cubicTo(16.1, 14.4, 19.4, 16.6, 19.4, 20.4);
  });

  // -- Actions --------------------------------------------------------------
  static final plus = AppIconData((p) {
    _line(p, 12, 5, 12, 19);
    _line(p, 5, 12, 19, 12);
  });

  static final search = AppIconData((p) {
    _circle(p, 11, 11, 6.6);
    _line(p, 15.9, 15.9, 20.4, 20.4);
  });

  static final close = AppIconData((p) {
    _line(p, 6.2, 6.2, 17.8, 17.8);
    _line(p, 17.8, 6.2, 6.2, 17.8);
  });

  static final check = AppIconData((p) {
    _poly(p, [5, 12.6, 9.8, 17.4, 19, 6.6]);
  });

  static final chevronLeft = AppIconData((p) => _poly(p, [14.5, 4.8, 8, 12, 14.5, 19.2]));
  static final chevronRight = AppIconData((p) => _poly(p, [9.5, 4.8, 16, 12, 9.5, 19.2]));
  static final chevronDown = AppIconData((p) => _poly(p, [5.2, 9, 12, 15.8, 18.8, 9]));
  static final chevronUp = AppIconData((p) => _poly(p, [5.2, 15, 12, 8.2, 18.8, 15]));

  static final trash = AppIconData((p) {
    _line(p, 3.8, 6.4, 20.2, 6.4);
    p.moveTo(9, 6.4);
    p.lineTo(9, 4.6);
    p.cubicTo(9, 3.9, 9.4, 3.5, 10.1, 3.5);
    p.lineTo(13.9, 3.5);
    p.cubicTo(14.6, 3.5, 15, 3.9, 15, 4.6);
    p.lineTo(15, 6.4);
    p.moveTo(6.5, 6.4);
    p.lineTo(7.4, 19.9);
    p.cubicTo(7.45, 20.7, 8.05, 21.2, 8.8, 21.2);
    p.lineTo(15.2, 21.2);
    p.cubicTo(15.95, 21.2, 16.55, 20.7, 16.6, 19.9);
    p.lineTo(17.5, 6.4);
    _line(p, 10.3, 10.4, 10.3, 17.4);
    _line(p, 13.7, 10.4, 13.7, 17.4);
  });

  static final pencil = AppIconData((p) {
    p.moveTo(4, 20.1);
    p.lineTo(4.25, 16.4);
    p.lineTo(15.6, 5.05);
    p.cubicTo(16.3, 4.35, 17.4, 4.35, 18.1, 5.05);
    p.lineTo(19.05, 6.0);
    p.cubicTo(19.75, 6.7, 19.75, 7.8, 19.05, 8.5);
    p.lineTo(7.7, 19.85);
    p.close();
    _line(p, 14.3, 6.4, 17.7, 9.8);
  });

  static final download = AppIconData((p) {
    _line(p, 12, 3.6, 12, 15.6);
    _poly(p, [7, 10.8, 12, 15.8, 17, 10.8]);
    _line(p, 4.6, 19.6, 19.4, 19.6);
  });

  static final share = AppIconData((p) {
    _circle(p, 17.8, 5.6, 2.8);
    _circle(p, 6.2, 12, 2.8);
    _circle(p, 17.8, 18.4, 2.8);
    _line(p, 8.7, 10.7, 15.4, 6.9);
    _line(p, 8.7, 13.3, 15.4, 17.1);
  });

  static final calendar = AppIconData((p) {
    _rrect(p, 3.5, 5, 17, 16, 2.2);
    _line(p, 8, 3, 8, 7.2);
    _line(p, 16, 3, 16, 7.2);
    _line(p, 3.5, 10, 20.5, 10);
  });

  static final filter = AppIconData((p) {
    _line(p, 3.5, 7, 20.5, 7);
    _line(p, 3.5, 12, 20.5, 12);
    _line(p, 3.5, 17, 20.5, 17);
    _circle(p, 9, 7, 2.1);
    _circle(p, 15.5, 12, 2.1);
    _circle(p, 7, 17, 2.1);
  });

  static final sort = AppIconData((p) {
    _line(p, 7, 20, 7, 4.2);
    _poly(p, [3.5, 7.7, 7, 4.2, 10.5, 7.7]);
    _line(p, 13.5, 8, 20.5, 8);
    _line(p, 13.5, 13, 18.5, 13);
    _line(p, 13.5, 18, 16.5, 18);
  });

  static final bell = AppIconData((p) {
    p.moveTo(6, 9.6);
    p.cubicTo(6, 6.3, 8.7, 3.6, 12, 3.6);
    p.cubicTo(15.3, 3.6, 18, 6.3, 18, 9.6);
    p.lineTo(18, 14.1);
    p.lineTo(19.8, 17.1);
    p.lineTo(4.2, 17.1);
    p.lineTo(6, 14.1);
    p.close();
    p.moveTo(10, 19.6);
    p.cubicTo(10.4, 20.7, 11.15, 21.3, 12, 21.3);
    p.cubicTo(12.85, 21.3, 13.6, 20.7, 14, 19.6);
  });

  // -- Channels -------------------------------------------------------------
  static final cash = AppIconData((p) {
    _rrect(p, 2.5, 6.4, 19, 11.2, 2.2);
    _circle(p, 12, 12, 2.7);
    _line(p, 6, 11, 6, 13);
    _line(p, 18, 11, 18, 13);
  });

  static final qr = AppIconData((p) {
    _rrect(p, 3.5, 3.5, 6.2, 6.2, 1.2);
    _rrect(p, 14.3, 3.5, 6.2, 6.2, 1.2);
    _rrect(p, 3.5, 14.3, 6.2, 6.2, 1.2);
    _line(p, 14.3, 14.3, 17.2, 14.3);
    _line(p, 20.5, 14.3, 20.5, 17.2);
    _poly(p, [14.3, 17.6, 14.3, 20.5, 17.4, 20.5]);
    _line(p, 20.5, 20.5, 20.5, 20.5);
    _dot(p, 20.5, 20.5);
  });

  static final card = AppIconData((p) {
    _rrect(p, 2.5, 5, 19, 14, 2.4);
    _line(p, 2.5, 9.8, 21.5, 9.8);
    _line(p, 6, 14.6, 10.2, 14.6);
  });

  /// Fiado issued — money leaving the merchant.
  static final arrowOut = AppIconData((p) {
    _line(p, 6.8, 17.2, 17.2, 6.8);
    _poly(p, [9.4, 6.8, 17.2, 6.8, 17.2, 14.6]);
  });

  /// Fiado collected — money coming back in.
  static final arrowIn = AppIconData((p) {
    _line(p, 17.2, 6.8, 6.8, 17.2);
    _poly(p, [14.6, 17.2, 6.8, 17.2, 6.8, 9.4]);
  });

  static final arrowUp = AppIconData((p) {
    _line(p, 12, 19.2, 12, 4.8);
    _poly(p, [6.2, 10.6, 12, 4.8, 17.8, 10.6]);
  });

  static final arrowDown = AppIconData((p) {
    _line(p, 12, 4.8, 12, 19.2);
    _poly(p, [6.2, 13.4, 12, 19.2, 17.8, 13.4]);
  });

  // -- Status ---------------------------------------------------------------
  static final alert = AppIconData((p) {
    p.moveTo(12, 3.9);
    p.lineTo(21.3, 19.5);
    p.cubicTo(21.75, 20.25, 21.2, 21.2, 20.35, 21.2);
    p.lineTo(3.65, 21.2);
    p.cubicTo(2.8, 21.2, 2.25, 20.25, 2.7, 19.5);
    p.close();
    _line(p, 12, 9.6, 12, 14.6);
    _dot(p, 12, 17.6);
  });

  static final info = AppIconData((p) {
    _circle(p, 12, 12, 8.6);
    _line(p, 12, 11.2, 12, 16.6);
    _dot(p, 12, 7.9);
  });

  static final moon = AppIconData((p) {
    p.moveTo(20.4, 14.4);
    p.arcToPoint(const Offset(9.6, 3.6), radius: const Radius.circular(8.7), clockwise: false);
    p.arcToPoint(const Offset(20.4, 14.4), radius: const Radius.circular(6.9), clockwise: true);
    p.close();
  });

  static final phone = AppIconData((p) {
    p.moveTo(6.4, 3.6);
    p.lineTo(9.4, 3.6);
    p.lineTo(10.9, 8.0);
    p.lineTo(8.7, 9.4);
    p.cubicTo(9.8, 11.6, 12.4, 14.2, 14.6, 15.3);
    p.lineTo(16, 13.1);
    p.lineTo(20.4, 14.6);
    p.lineTo(20.4, 17.6);
    p.cubicTo(20.4, 19.5, 18.9, 20.8, 17.1, 20.5);
    p.cubicTo(10.4, 19.4, 4.6, 13.6, 3.5, 6.9);
    p.cubicTo(3.2, 5.1, 4.5, 3.6, 6.4, 3.6);
    p.close();
  });

  static final wallet = AppIconData((p) {
    _rrect(p, 3, 5.5, 18, 14, 2.6);
    _line(p, 3, 10.2, 21, 10.2);
    _circle(p, 16.6, 14.8, 1.4);
  });

  static final settings = AppIconData((p) {
    _circle(p, 12, 12, 3.2);
    _line(p, 12, 2.8, 12, 5.4);
    _line(p, 12, 18.6, 12, 21.2);
    _line(p, 2.8, 12, 5.4, 12);
    _line(p, 18.6, 12, 21.2, 12);
    _line(p, 5.5, 5.5, 7.3, 7.3);
    _line(p, 16.7, 16.7, 18.5, 18.5);
    _line(p, 18.5, 5.5, 16.7, 7.3);
    _line(p, 7.3, 16.7, 5.5, 18.5);
  });
}
