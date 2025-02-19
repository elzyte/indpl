import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'draw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


void main() async {
  runApp(MyApp());
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
  final String espIp = "http://192.168.1.84"; // Replace with actual ESP32 IP
  Timer? _timer;
  String? deviceName;
  bool isPolling = true;
  Map<String, Color> userColors = {};
  List<Color> _wheelColors = [];
  List<String> _wheelItems = [];
  List<String> lastUsers = [];

  late FlutterLocalNotificationsPlugin localNotifications;

  final List<Color> _allowedColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.yellow,
    const Color.fromARGB(255, 235, 119, 255)
  ];

  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  double _currentRotation = 0; // Keeps track of current angle
  int serverCounter = 0;
  int lastCounter = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(_controller);

    _startFetchingUsers();
    _fetchServerCounter();
    _loadDeviceName();
  }

  Future<void> _fetchServerCounter() async {
    try {
      final response = await http.get(
        Uri.parse("$espIp/fetchcounter"),
        headers: {"Accept": "application/json"},
      );
      if (response.statusCode == 200) {
        print("Response received: ${response.body}");
        Map<String, dynamic> data = jsonDecode(response.body);
        int serverCounter = int.parse(data["counter"]);
        setState(() {
          print("item length ${_wheelItems.length}");
          print("serverCounter: $serverCounter");
          lastCounter = serverCounter;
        });
      }
    } catch (e) {
      print("Polling error: $e");
    }
  }

  void _assignColors() {
    int index = 0;
    for (String user in _wheelItems) {
      Color newColor = _allowedColors[index];
      userColors[user] = newColor;
      index++;
    }
    _wheelColors = _wheelItems.map((user) => userColors[user]!).toList();

    print("User Colors Assigned: $userColors"); // Debugging log
  }

  Future<void> _sendUserName(String name) async {
    final response =
        await http.post(Uri.parse("$espIp/namecheck"), body: {"name": name});
    if (response.statusCode == 200) {
      _startFetchingUsers();
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
                      _wheelItems.add(enteredName);
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
        final response = await http.get(
          Uri.parse("$espIp/fetchcounter"),
          headers: {"Accept": "application/json"},
        );
        if (response.statusCode == 200) {
          print("Response received: ${response.body}");
          Map<String, dynamic> data =
              jsonDecode(response.body); // Decode full JSON object
          serverCounter = int.parse(data["counter"]);
          print("Last counter: $lastCounter");
          if (serverCounter > lastCounter && _wheelItems.length > 1) {
            print("Counter increased!");
            lastCounter++;
            print("Last counter: $lastCounter");
            _spinWheelLeft(); // Call animation function
          } else if (serverCounter < lastCounter && _wheelItems.length > 1) {
            lastCounter--;
            _spinWheelRight();
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

  Future<void> _flagToDecrementCounter() async {
    try {
      isPolling = false;
      print("Flagged to decrement counter");
      final response = await http.post(Uri.parse("$espIp/decrement"));
      if (response.statusCode == 200) {
        print("successfully sent the flag. Full handshake.");
      }
      isPolling = true;
      _startPolling();
    } catch (e) {
      print("Error in _flagToDecrementCounter: $e");
    }
  }

  void _startFetchingUsers() {
    Timer.periodic(Duration(seconds: 5), (timer) async {
      await _loadWheelItems();
    });
  }

  Future<void> _loadWheelItems() async {
    try {
      final response = await http.get(
        Uri.parse("$espIp/fetchusers"),
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        print("Response received: ${response.body}");
        Map<String, dynamic> data = jsonDecode(response.body);

        List<String> newUsers =
            List<String>.from(data["users"]); // Extract users
        final listEquality = const ListEquality();

        if (!listEquality.equals(newUsers, lastUsers)) {
          setState(() {
            _wheelItems = newUsers;
            _assignColors(); // Reassign colors if needed

            // Reset rotation if a new user is added
            if (_wheelItems.isNotEmpty) {
              _currentRotation = 0;
              _rotationAnimation = Tween<double>(
                begin: _currentRotation,
                end: _currentRotation,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ));
            }
          });
        }
        lastUsers = newUsers.toList();
      } else {
        print("Failed to load wheel items.");
      }
    } catch (e) {
      print("Error fetching wheel items: $e");
    }
  }

  void _spinWheelLeft() {
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

  void _spinWheelRight() {
    setState(() {
      _currentRotation -=
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
            if (_wheelItems.isNotEmpty) // Only render when items exist
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return SpinningWheel(
                    items: _wheelItems,
                    colors: _wheelColors,
                    rotationAngle: _rotationAnimation.value,
                  );
                },
              )
            else
              SizedBox.shrink(), // Render nothing if wheel is empty
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              ElevatedButton(
                onPressed: _flagToIncrementCounter, // Your function
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        8), // Adjust for sharp or rounded corners
                  ),
                  padding: const EdgeInsets.all(16), // Adjusts button size
                  backgroundColor: Colors.grey[300], // Light grey background
                  foregroundColor: Colors.purple, // Icon color
                  shadowColor: Colors.grey[400], // Optional shadow effect
                  elevation: 4, // Depth effect
                ),
                child: const Icon(Icons.arrow_back_ios_sharp,
                    size: 30), // Left arrow
              ),
              const SizedBox(width: 10), // Space between buttons
              ElevatedButton(
                onPressed: _flagToDecrementCounter, // Your function
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        8), // Adjust for sharp or rounded corners
                  ),
                  padding: const EdgeInsets.all(16), // Adjusts button size
                  backgroundColor: Colors.grey[300], // Light grey background
                  foregroundColor: Colors.purple, // Icon color
                  shadowColor: Colors.grey[400], // Optional shadow effect
                  elevation: 4, // Depth effect
                ),
                child: const Icon(Icons.arrow_forward_ios_sharp,
                    size: 30), // Left arrow
              ),
            ])
          ],
        ),
      ),
    );
  }
}
*/
