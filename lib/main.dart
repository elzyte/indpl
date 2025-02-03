import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

void main() {
  runApp(const MyApp());
}

Path buildSlicePath(double radius, double startAngle, double sweepAngle) {
  Path path = Path();
  path.moveTo(0, 0); // Start at the center of the circle
  path.arcTo(
    Rect.fromCircle(center: Offset(0, 0), radius: radius),
    startAngle, // Start angle in radians
    sweepAngle, // Angle of the slice
    false,
  );
  path.close(); // Close the path to form a complete shape
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
          pi / 2, // Sweep angle (90 degrees, 1/4 of a full circle)
          Colors.blue // Correctly assigned as the color
          ),
    );
  }
}

class SpinningWheel extends StatelessWidget {
  final List<String> items;
  final List<Color> colors;
  final double rotationAngle;

  SpinningWheel(
      {required this.items, required this.colors, required this.rotationAngle});

  @override
  Widget build(BuildContext context) {
    double sliceAngle = (2 * pi) / items.length;
    double wheelRadius = 125; // Half of 250x250 wheel size
    double textRadius = wheelRadius * 0.8; // Move text closer to the outer edge

    return Transform.rotate(
      // Rotate entire wheel together
      angle: rotationAngle,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(items.length, (index) {
          double startAngle = index * sliceAngle + pi / 4;
          double textAngle =
              startAngle + sliceAngle / 2; // Center text in slice

          return Stack(
            alignment: Alignment.center,
            children: [
              // Draw the slice
              CustomPaint(
                size: const Size(250, 250),
                painter:
                    CircleSlicePainter(startAngle, sliceAngle, colors[index]),
              ),
              // Position the text dynamically
              Positioned(
                left: 125 + textRadius * cos(textAngle), // Adjust X position
                top: 125 + textRadius * sin(textAngle), // Adjust Y position
                child: Transform.rotate(
                  angle: textAngle + pi / 2, // Ensure text faces center
                  child: CustomPaint(
                    painter: TextPainterHelper(
                        items[index]), // Use helper to center text
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dishwasher Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Indaplovė'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final String espIp = "http://192.168.79.32"; // Replace with actual ESP32 IP
  Timer? _timer;
  String? deviceName;
  bool isPolling = true;
  List<Color> _wheelColors = [];
  List<String> _wheelItems = [];
  final List<Color> _allowedColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    const Color.fromARGB(255, 235, 119, 255),
    Colors.orange,
  ];

  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  double _currentRotation = 0; // Keeps track of current angle

  @override
  void initState() {
    super.initState();
    _assignRandomColors(); // Generate random colors from allowed list
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Smooth 90-degree animation
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _loadDeviceName();
  }

  void _assignRandomColors() {
    if (_allowedColors.length < _wheelItems.length) {
      throw Exception("Not enough unique colors for all slices!");
    }

    List<Color> shuffledColors = List.of(_allowedColors)
      ..shuffle(); // Shuffle colors list
    _wheelColors = shuffledColors.sublist(
        0, _wheelItems.length); // Pick first N unique colors
  }

  Future<void> _sendUserName(String name) async {
    final response =
        await http.post(Uri.parse("$espIp/namecheck"), body: {"name": name});
    if (response.statusCode == 200) {
      _loadWheelItems();
      _startPolling();
    } else {
      print("Error: $response.statusCode");
    }
  }

  Future<void> _loadDeviceName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('device_name');
    if (name == null) {
      _askForName();
    } else {
      setState(() {
        deviceName = name;
        _sendUserName(name);
      });
    }
  }

  Future<void> _askForName() async {
    String? name = await showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        String? errorMessage; // Holds error message if name is taken

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Enter your name"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: controller),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorMessage ?? "",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    String enteredName = controller.text.trim();

                    if (enteredName.isEmpty) {
                      setState(() {
                        errorMessage = "Name cannot be empty.";
                      });
                      return;
                    }

                    // Check name with ESP32 before closing
                    try {
                      final response = await http
                          .post(Uri.parse("$espIp/nameregister"), headers: {
                        "Content-Type": "application/x-www-form-urlencoded"
                      }, body: {
                        "name": enteredName
                      });
                      print("Response Status: ${response.statusCode}");
                      print(
                          "Response Body: ${response.body}"); // Print response body
                      if (response.statusCode == 200) {
                        if (response.body
                            .contains("Username is already taken")) {
                          setState(() {
                            errorMessage = "This username is already taken.";
                          });
                        } else {
                          Navigator.of(context).pop(enteredName);
                        }
                      } else {
                        setState(() {
                          errorMessage = "Server error: ${response.statusCode}";
                        });
                      }
                    } catch (e) {
                      print("Error sending request: $e");
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );

    // Save name after successful check
    if (name != null && name.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', name);
      setState(() {
        deviceName = name;
      });
      _loadWheelItems();
      _startPolling();
      print("sends Username to ESP");
      //_sendUserName(name); // Send the valid name to ESP32
    }
  }

  void _startPolling() {
    Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!isPolling) {
        timer.cancel(); // Stop polling if needed
        return;
      }

      try {
        final response = await http.get(Uri.parse("$espIp/fetchcounter"));
        if (response.statusCode == 200) {
          bool counterIncreased = response.body.trim() == "true";
          if (counterIncreased) {
            print("Counter increased!");
            _spinWheel(); // Call animation function
          }
        }
      } catch (e) {
        print("Polling error: $e");
      }
    });
  }

  Future<void> _flagToIncrementCounter() async {
    try {
      isPolling = false;
      print("Flagged to increment counter");
      final response = await http.post(Uri.parse("$espIp/increment"));
      if (response.statusCode == 200) {
        print("successfully sent the flag. Full handshake.");
      }
      isPolling = true;
      _startPolling();
    } catch (e) {
      print("Error in _flagToIncrementCounter: $e");
    }
  }

Future<void> _loadWheelItems() async {
  final response = await http.get(Uri.parse("$espIp/fetchusers"));

  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body); // Decode full JSON object
    setState(() {
      _wheelItems = List<String>.from(data["users"]); // Extract 'users' array
    });
  } else {
    print("Failed to load wheel items.");
  }
}

  void _spinWheel() {
    setState(() {
      _currentRotation +=
          (pi * 2) / _wheelItems.length; // Ensure only 1 segment rotation
      _rotationAnimation = Tween<double>(
        begin: _rotationAnimation.value,
        end: _currentRotation,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut, // Smooth animation
      ));
    });

    _controller.forward(from: 0); // Start animation smoothly
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return SpinningWheel(
                  items: _wheelItems,
                  colors: _wheelColors,
                  rotationAngle: _rotationAnimation
                      .value, // Apply rotation only inside SpinningWheel
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _flagToIncrementCounter,
              child: const Text("Spin the Wheel"),
            ),
          ],
        ),
      ),
    );
  }
}
