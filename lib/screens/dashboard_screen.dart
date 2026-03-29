import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedRoute;
  DatabaseReference? _patientRef;
  String? _uid;
  Stream<DatabaseEvent>? _dataStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _patientRef = FirebaseDatabase.instance.ref(
        "users/$_uid/patients/dominic",
      );
      // 2. Initialize the stream here
      _dataStream = _patientRef!.onValue;
    }
  }

  void _toggleBuzzer(bool currentState) {
    _patientRef?.child("commands").update({"ringBuzzer": !currentState});
  }

  String _formatScheduledTime(String? militaryTime) {
    if (militaryTime == null || militaryTime == "--:--") return "--:--";
    try {
      final inputFormat = DateFormat("HH:mm");
      final outputFormat = DateFormat("hh:mm a");
      return outputFormat.format(inputFormat.parse(militaryTime));
    } catch (e) {
      return militaryTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_patientRef == null || _dataStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const mintBg = Color(0xFFE6F7F0);
    const orangePrimary = Color(0xFFFFAA45);
    const darkBlue = Color(0xFF5D84A0);
    const alertRed = Color(0xFFE74C3C); // Added Red for Alarm

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFB),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _dataStream, // Using the persisted stream
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: Text("No data in Firebase"));
            }

            final data = Map<dynamic, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );
            final scheduleMap = data['schedule'] ?? {};
            final logsMap = data['logs'] ?? {};
            final bool isBuzzerOn = data['commands']?['ringBuzzer'] ?? false;

            /* Map<String, dynamic> getTodaySlot(String slotName) {
              final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

              final scheduledTimeRaw =
                  scheduleMap[slotName]?['time'] ?? "--:--";

              final scheduledTimeFormatted = _formatScheduledTime(
                scheduledTimeRaw,
              );

              final todayLogs = logsMap[todayKey]?[slotName];

              if (todayLogs == null) {
                return {
                  "status": "Scheduled",
                  "scheduledTime": scheduledTimeFormatted,
                  "takenTime": null,
                };
              }

              final status = todayLogs["status"];

              final rawTimestamp = todayLogs["timestamp"];
              final int timestamp = rawTimestamp is String
                  ? int.parse(rawTimestamp)
                  : rawTimestamp;

              final takenTime = DateTime.fromMillisecondsSinceEpoch(
                timestamp,
              ).toLocal();

              return {
                "status": status,
                "scheduledTime": scheduledTimeFormatted,
                "takenTime": DateFormat('hh:mm a').format(takenTime),
              };
            }*/
            // Inside _DashboardScreenState ...

            /*Map<String, dynamic> getTodaySlot(String slotName, Map data) {
              final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

              // 1. Get Scheduled Time
              final scheduleMap = data['schedule'] ?? {};
              final String scheduledTimeRaw =
                  scheduleMap[slotName]?['time'] ?? "--:--";
              final String scheduledTimeFormatted = _formatScheduledTime(
                scheduledTimeRaw,
              );

              // 2. Get Real-time Hardware Status (The 1/0 from Ultrasonics)
              // Logic: if 1, pill is there. If 0, pill is removed.
              final realtimeMap = data['realtimeStatus'] ?? {};
              final int hardwareValue = realtimeMap[slotName] ?? 1;
              final bool isPillPhysicallyPresent = hardwareValue == 1;

              // 3. Get Logs for "Missed" status or historical Taken time
              final logsMap = data['logs'] ?? {};
              final todayLogs = logsMap[todayKey]?[slotName];
              final String? loggedStatus = todayLogs?["status"];

              // --- LOGIC ENGINE ---
              String displayStatus = "Scheduled";
              String? takenTimeStr;

              if (!isPillPhysicallyPresent) {
                // If the pill is gone according to ultrasonic
                displayStatus = "Taken";
                if (todayLogs != null && todayLogs["timestamp"] != null) {
                  final int ts = todayLogs["timestamp"] is String
                      ? int.parse(todayLogs["timestamp"])
                      : todayLogs["timestamp"];
                  takenTimeStr = DateFormat(
                    'hh:mm a',
                  ).format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());
                }
              } else if (loggedStatus == "Missed") {
                displayStatus = "Missed";
              }

              return {
                "status": displayStatus,
                "scheduledTime": scheduledTimeFormatted,
                "takenTime": takenTimeStr,
                "isPillPresent": isPillPhysicallyPresent, // Pass this to UI
              };
            }*/

            Map<String, dynamic> getTodaySlot(String slotName, Map data) {
              final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

              // 1. Extract Schedule
              final scheduleMap = data['schedule'] ?? {};
              final String scheduledTimeRaw =
                  scheduleMap[slotName]?['time'] ?? "--:--";
              final String scheduledTimeFormatted = _formatScheduledTime(
                scheduledTimeRaw,
              );

              // 2. Extract Hardware Status
              final realtimeMap = data['realtimeStatus'] ?? {};
              //final int hardwareValue = realtimeMap[slotName] ?? 1;
              //final realtimeSlot = realtimeMap[slotName] ?? {};
              final int hardwareValue = realtimeMap[slotName] ?? 1;
              final bool isPillPhysicallyPresent = (hardwareValue == 1);

              // 3. Extract Logs
              final logsMap = data['logs'] ?? {};
              final todayLogs = logsMap[todayKey]?[slotName];
              final String? loggedStatus = todayLogs?["status"];

              String? formattedTakenTime;
              /*if (todayLogs != null && todayLogs["timestamp"] != null) {
                try {
                  final rawTs = todayLogs["timestamp"];
                  // Handle both String and Int timestamps from Firebase
                  final int ts = rawTs is String
                      ? int.parse(rawTs)
                      : rawTs as int;

                  // Check if it's seconds or milliseconds (Firebase usually ms)
                  /*final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                    ts,
                  ).toLocal();*/
                  final int adjustedTs = ts.toString().length == 10
                      ? ts * 1000
                      : ts;

                  final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                    adjustedTs,
                  );
                  formattedTakenTime = DateFormat('hh:mm a').format(dt);
                } catch (e) {
                  formattedTakenTime = null;
                }
              }*/

              if (todayLogs != null && todayLogs["timestamp"] != null) {
                try {
                  final rawTs = todayLogs["timestamp"];
                  final int ts = rawTs is String
                      ? int.parse(rawTs)
                      : rawTs as int;

                  final int adjustedTs = ts.toString().length == 10
                      ? ts * 1000
                      : ts;

                  final correctedTs =
                      adjustedTs - (5 * 60 * 60 * 1000) - (30 * 60 * 1000);

                  final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                    correctedTs,
                    isUtc: true,
                  ).toLocal();

                  formattedTakenTime = DateFormat('hh:mm a').format(dt);
                } catch (e) {
                  formattedTakenTime = null;
                }
              }
              // --- UI STATE LOGIC ---
              String displayStatus = "Scheduled";

              // If sensor says pill is gone, it's TAKEN
              if (!isPillPhysicallyPresent) {
                displayStatus = "Taken";
              }
              // If sensor says pill is there, but log says missed
              else if (loggedStatus == "Missed") {
                displayStatus = "Missed";
              }

              return {
                "status": displayStatus,
                "scheduledTime": scheduledTimeFormatted,
                "takenTime": formattedTakenTime,
                "isPillPresent": isPillPhysicallyPresent,
              };
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildHeader(mintBg),
                  const SizedBox(height: 30),
                  _sectionTitle("TODAY'S SCHEDULE", Colors.grey),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScheduleBox(
                        title: "Morning",
                        data: getTodaySlot("Morning", data),
                      ),
                      _ScheduleBox(
                        title: "Noon",
                        data: getTodaySlot("Noon", data),
                      ),
                      _ScheduleBox(
                        title: "Evening",
                        data: getTodaySlot("Evening", data),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _sectionTitle("QUICK ACTIONS", Colors.grey),
                  const SizedBox(height: 20),
                  _buildCircularBuzzer(isBuzzerOn, alertRed),
                  const SizedBox(height: 30),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      _gridButton(
                        "History",
                        Icons.history,
                        darkBlue,
                        '/history',
                      ),
                      _gridButton(
                        "Statistics",
                        Icons.leaderboard,
                        darkBlue,
                        '/statistics',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildChooseButton(orangePrimary),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildHeader(Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Row(
        children: [
          Text(
            "Dominic's Health",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: color,
        ),
      ),
    );
  }

  // RED ALARM STYLE BUZZER
  Widget _buildAlarmTile(bool isOn, Color activeColor) {
    return InkWell(
      onTap: () => _toggleBuzzer(isOn),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOn ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isOn
                  ? activeColor.withOpacity(0.4)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isOn ? Icons.notifications_active : Icons.notifications_none,
              color: isOn ? Colors.white : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 15),
            Text(
              isOn ? "BUZZER RINGING" : "Ring Remote Buzzer",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOn ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Switch(
              value: isOn,
              activeColor: Colors.white,
              activeTrackColor: Colors.black26,
              onChanged: (val) => _toggleBuzzer(isOn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChooseButton(Color color) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (selectedRoute != null) {
            Navigator.pushNamed(context, selectedRoute!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select an option first")),
            );
          }
        },
        child: Container(
          width: double.infinity,
          height: 60,
          alignment: Alignment.center,
          child: const Text(
            "CHOOSE",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridButton(String text, IconData icon, Color color, String route) {
    final bool isSelected = selectedRoute == route;
    return GestureDetector(
      onTap: () => setState(() => selectedRoute = route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: isSelected
            ? Matrix4.translationValues(0, 6, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32),
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularBuzzer(bool isOn, Color activeColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _toggleBuzzer(isOn),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Pulse/Glow Effect when ON
              if (isOn)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.2),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Container(
                      width: 100 * value,
                      height: 100 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withOpacity(0.2),
                      ),
                    );
                  },
                ),
              // Main Circular Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? activeColor : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: isOn
                          ? activeColor.withOpacity(0.5)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: isOn
                        ? Colors.white.withOpacity(0.5)
                        : Colors.transparent,
                    width: 4,
                  ),
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 45,
                  color: isOn ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isOn ? "STOP BUZZER" : "RING BUZZER",
          style: TextStyle(
            color: isOn ? activeColor : Colors.grey,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// --- UPDATED SCHEDULE BOX WITH RED GLOW ---

/*class _ScheduleBox extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _ScheduleBox({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    /*final String status = data["status"];
    final String time = data["time"];
    final bool isTaken = status == "Taken";
    final bool isMissed =
        status == "Missed" ||
        (status == "Scheduled" && _isCurrentlyMissed(time));
*/
    final String status = data["status"];
    final String scheduledTime = data["scheduledTime"] ?? "--:--";
    final String? takenTime = data["takenTime"];

    final bool isTaken = status == "Taken";
    final bool isMissed = status == "Missed";
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMissed ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 0.8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final width = constraints.maxWidth;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isMissed) // RED GLOW
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      CustomPaint(
                        painter: MedicineContainerPainter(
                          bodyColor: const Color(0xFFA3C1D4),
                          lidColor: const Color(0xFF5D84A0),
                          borderColor: Colors.transparent,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        top: height * 0.08,
                        child: Text(
                          scheduledTime,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        top: isTaken ? height * 0.45 : height * 0.38,
                        child: isTaken
                            ? const Icon(
                                Icons.check_circle,
                                size: 40,
                                color: Color(0xFF27AE60),
                              )
                            : SizedBox(
                                width: width * 0.8,
                                height: height * 0.4,
                                child: CustomPaint(painter: PillsPilePainter()),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            /* const SizedBox(height: 10),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMissed ? Colors.red : Colors.black87,
              ),
            ),*/
            const SizedBox(height: 10),

            if (isMissed)
              const Text(
                "MISSED",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              )
            else if (isTaken)
              Text(
                "Taken at ${takenTime ?? '--:--'}",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27AE60),
                ),
              )
            else
              const Text(
                "SCHEDULED",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            /*const SizedBox(height: 4),
            Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isTaken
                    ? const Color(0xFF27AE60)
                    : (isMissed ? Colors.red : Colors.grey),
              ),
            ),*/
          ],
        ),
      ),
    );
  }

  bool _isCurrentlyMissed(String time) {
    if (time == "--:--") return false;
    // Basic logic to check if current time is past scheduled time if status is still Scheduled
    return false; // Firebase usually handles the 'Missed' status update
  }
}*/

/*class _ScheduleBox extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _ScheduleBox({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final String status = data["status"];
    final String scheduledTime = data["scheduledTime"] ?? "--:--";
    final String? takenTime = data["takenTime"];
    final bool isPillPresent = data["isPillPresent"] ?? true;

    final bool isTaken = status == "Taken";
    final bool isMissed = status == "Missed";

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMissed ? Colors.red : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 0.75,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final width = constraints.maxWidth;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isMissed)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      // The Box Container
                      CustomPaint(
                        painter: MedicineContainerPainter(
                          bodyColor: isPillPresent
                              ? const Color(0xFFA3C1D4)
                              : const Color(0xFFA3C1D4).withOpacity(0.4),
                          lidColor: const Color(0xFF5D84A0),
                          borderColor: Colors.transparent,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      // Scheduled Time Label on the lid
                      Positioned(
                        top: height * 0.08,
                        child: Text(
                          scheduledTime,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Real-time Content: Show pills if present, checkmark if taken
                      Positioned(
                        top: !isPillPresent ? height * 0.45 : height * 0.38,
                        child: !isPillPresent
                            ? const Icon(
                                Icons.check_circle,
                                size: 32,
                                color: Color(0xFF27AE60),
                              )
                            : SizedBox(
                                width: width * 0.7,
                                height: height * 0.4,
                                child: CustomPaint(painter: PillsPilePainter()),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Bottom Status Text
            if (isMissed)
              const Text(
                "MISSED",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              )
            else if (isTaken)
              Text(
                takenTime != null ? "Taken $takenTime" : "Taken",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27AE60),
                ),
              )
            else
              const Text(
                "SCHEDULED",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}*/

class _ScheduleBox extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _ScheduleBox({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final String status = data["status"];
    final String scheduledTime = data["scheduledTime"] ?? "--:--";
    final String? takenTime = data["takenTime"];
    final bool isPillPresent = data["isPillPresent"] ?? true;

    final bool isTaken = (status == "Taken");
    final bool isMissed = (status == "Missed");

    return Expanded(
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMissed ? Colors.red : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 0.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isMissed)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                // Pill Bottle Drawing
                CustomPaint(
                  painter: MedicineContainerPainter(
                    bodyColor: isPillPresent
                        ? const Color(0xFFA3C1D4)
                        : const Color(0xFFD1E0E9),
                    lidColor: const Color(0xFF5D84A0),
                    borderColor: Colors.transparent,
                  ),
                  child: const SizedBox.expand(),
                ),
                // Time on Lid
                Positioned(
                  top: 10,
                  child: Text(
                    scheduledTime,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Pill Content or Checkmark
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: isPillPresent
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: CustomPaint(painter: PillsPilePainter()),
                          )
                        : const Icon(
                            Icons.check_circle,
                            color: Color(0xFF27AE60),
                            size: 35,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // --- BOTTOM TEXT SECTION ---
          if (isTaken) ...[
            const Text(
              "TAKEN",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            Text(
              takenTime != null ? "at $takenTime" : "just now",
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ] else if (isMissed) ...[
            const Text(
              "MISSED",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ] else ...[
            const Text(
              "SCHEDULED",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MedicineContainerPainter extends CustomPainter {
  final Color bodyColor;
  final Color lidColor;
  final Color borderColor;

  MedicineContainerPainter({
    required this.bodyColor,
    required this.lidColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final lidPaint = Paint()
      ..color = lidColor
      ..style = PaintingStyle.fill;

    // BODY (tapered shape)
    final bodyPath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..lineTo(size.width * 0.85, size.height * 0.25)
      ..lineTo(size.width * 0.75, size.height * 0.95)
      ..lineTo(size.width * 0.25, size.height * 0.95)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, borderPaint);

    // LID
    final lidPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.95, size.height * 0.25)
      ..lineTo(size.width * 0.05, size.height * 0.25)
      ..close();

    canvas.drawPath(lidPath, lidPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PillPainter extends CustomPainter {
  final Color color;

  PillPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(rect, paint);

    // middle divider
    final divider = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      divider,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PillsPilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF2E2E5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void drawCapsule(Rect rect, Color left, Color right) {
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.height / 2),
      );

      final leftRect = Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width / 2,
        rect.height,
      );

      final rightRect = Rect.fromLTWH(
        rect.left + rect.width / 2,
        rect.top,
        rect.width / 2,
        rect.height,
      );

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(leftRect, Paint()..color = left);
      canvas.drawRect(rightRect, Paint()..color = right);
      canvas.restore();

      canvas.drawRRect(rrect, outline);
    }

    void drawTablet(Offset center, double radius, Color color) {
      final paint = Paint()..color = color;
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius, outline);
    }

    // ---- Draw pills ----

    // Bottom tablets (slightly smaller)
    drawTablet(
      Offset(size.width * 0.38, size.height * 0.55),
      4, // was 5
      const Color(0xFF6DAEDB),
    );

    drawTablet(
      Offset(size.width * 0.5, size.height * 0.6),
      5, // was 6
      const Color(0xFFE85D75),
    );

    drawTablet(
      Offset(size.width * 0.62, size.height * 0.55),
      4, // was 5
      const Color(0xFFDDE6F1),
    );

    // Capsules (slightly smaller)
    drawCapsule(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.47, 20, 7), // was 24x9
      const Color(0xFFA05CD5),
      const Color(0xFFD9C2F3),
    );

    drawCapsule(
      Rect.fromLTWH(size.width * 0.52, size.height * 0.44, 20, 7),
      const Color(0xFF4CAF88),
      const Color(0xFFE85D75),
    );

    drawCapsule(
      Rect.fromLTWH(size.width * 0.28, size.height * 0.5, 20, 7),
      const Color(0xFFDDE6F1),
      const Color(0xFF6DAEDB),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
