import 'package:flutter/material.dart';
import 'dart:math';

Path buildSlicePath(double radius, double startAngle, double sweepAngle) {
  Path path = Path();
  path.moveTo(0, 0); // Start at the center of the circle

  if (sweepAngle >= 2 * pi) {
    path.addOval(Rect.fromCircle(center: Offset(0, 0), radius: radius));
  } else {
    path.arcTo(
      Rect.fromCircle(center: Offset(0, 0), radius: radius),
      startAngle, // Start angle in radians
      sweepAngle, // Angle of the slice
      false,
    );
    path.close(); // Close the path to form a complete shape
  }
  return path;
}

class CircleSlicePainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final Color color;

  CircleSlicePainter(this.startAngle, this.sweepAngle, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;

    canvas.translate(size.width / 2, size.height / 2); // Move to center
    final path = buildSlicePath(radius, startAngle, sweepAngle);

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class CircleSliceView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(250, 250), // Set a size for the wheel
      painter: CircleSlicePainter(
          0, // Start angle (first slice starts at 0)
          2 * pi, // Sweep angle (90 degrees, 1/4 of a full circle)
          Colors.blue // Correctly assigned as the color
          ),
    );
  }
}
class SpinningWheel extends StatefulWidget {
  final List<String> items;
  final List<Color> colors;
  final double rotationAngle;



  const SpinningWheel(
      {required this.items, required this.colors, required this.rotationAngle, Key? key,
  }) : super(key: key);


  @override
    _SpinningWheelState createState() => _SpinningWheelState();
  }
  class _SpinningWheelState extends State<SpinningWheel> {
  late double rotationAngle;
  
  @override
  Widget build(BuildContext context) {
    double sliceAngle = (2 * pi) / widget.items.length;
    double wheelRadius = 125; // Half of 250x250 wheel size
    double textRadius = wheelRadius * 0.8; // Move text closer to the outer edge
    double correctionAngle = -pi / 2 - sliceAngle / 2 - widget.rotationAngle;

    return Transform.rotate(
      // Rotate entire wheel together
      angle: correctionAngle,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(widget.items.length, (index) {
          double startAngle = index * sliceAngle;
          double textAngle =
              startAngle + sliceAngle / 2; // Center text in slice

          return Stack(
            alignment: Alignment.center,
            children: [
              // Draw the slice
              CustomPaint(
                size: const Size(250, 250),
                painter:
                    CircleSlicePainter(startAngle, sliceAngle, widget.colors[index]),
              ),
              // Position the text dynamically
              Positioned(
                left: 125 + textRadius * cos(textAngle), // Adjust X position
                top: 125 + textRadius * sin(textAngle), // Adjust Y position
                child: Transform.rotate(
                  angle: textAngle + pi / 2, // Ensure text faces center
                  child: CustomPaint(
                    painter: TextPainterHelper(
                        widget.items[index]), // Use helper to center text
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
  
}

class TextPainterHelper extends CustomPainter {
  final String text;
  TextPainterHelper(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(); // Measure text size

    // Center text properly
    Offset textOffset = Offset(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
