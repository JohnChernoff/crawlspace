import 'dart:math';
import 'package:flutter/material.dart';

class PentagramPainter extends CustomPainter {
  final Color color;
  final Color? borderCol;
  PentagramPainter(this.color,{this.borderCol});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = min(size.width, size.height) / 2;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final Path path = Path();

    for (int i = 0; i < 5; i++) {
      final double angle = (pi / 2) + (2 * pi * i * 2 / 5);
      final double x = centerX + radius * cos(angle);
      final double y = centerY - radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    if (borderCol != null) {
      paint = Paint()
        ..strokeWidth = 2
        ..color = borderCol!
        ..style = PaintingStyle.stroke;
      path.close();
      canvas.drawPath(path, paint);
    }
  }


  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HexagramPainter extends CustomPainter {
  final Color color;
  final Color? borderCol;
  HexagramPainter(this.color,{this.borderCol});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    Path triangle(double rotation) {
      final Path path = Path();
      for (int i = 0; i < 3; i++) {
        final angle = (2 * pi * i / 3) + rotation;
        final x = center.dx + radius * cos(angle);
        final y = center.dy + radius * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    }

    canvas.drawPath(triangle(0), paint);
    canvas.drawPath(triangle(pi), paint); // flipped triangle

    if (borderCol != null) {
      paint = Paint()
        ..strokeWidth = 2
        ..color = borderCol!
        ..style = PaintingStyle.stroke;
      canvas.drawPath(triangle(0), paint);
      canvas.drawPath(triangle(pi), paint); // flipped triangle
    }

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DiamondPainter extends CustomPainter {
  final Color color;
  final Color? borderCol;
  DiamondPainter(this.color,{this.borderCol});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.4;
    final ry = size.height * 0.45;

    final path = Path()
      ..moveTo(cx, cy - ry)   // top
      ..lineTo(cx + rx, cy)   // right
      ..lineTo(cx, cy + ry)   // bottom
      ..lineTo(cx - rx, cy)   // left
      ..close();

    canvas.drawPath(path, paint);

    if (borderCol != null) {
      paint = Paint()
        ..strokeWidth = 2
        ..color = borderCol!
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
