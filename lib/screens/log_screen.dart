import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  static const primaryColor = Color(0xFF13EC92);
  static const statusMissedColor = Color(0xFFFF4D4D);
  static const statusLateColor = Color(0xFFFFA500);

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  DateTimeRange? _selectedRange;
  bool _isFiltered = false;

  @override
  void initState() {
    super.initState();
    _resetToDefaultRange();
  }

  // 1. Reset logic remains similar but ensures full day coverage
  void _resetToDefaultRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _selectedRange = DateTimeRange(
        start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      _isFiltered = false;
    });
  }

  // 2. New Step-by-Step Picker
  Future<void> _pickDateRange() async {
    // A. Pick Year First
    final DateTime? pickedYear = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Year"),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            selectedDate: _selectedRange?.start ?? DateTime.now(),
            onChanged: (DateTime dateTime) => Navigator.pop(context, dateTime),
          ),
        ),
      ),
    );

    if (pickedYear == null) return;

    // B. Pick Month (Using a simple list dialog)
    final int? pickedMonth = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Month"),
        children: List.generate(12, (index) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index + 1),
            child: Text(DateFormat('MMMM').format(DateTime(0, index + 1))),
          );
        }),
      ),
    );

    if (pickedMonth == null) return;

    // C. Pick specific Day or Range within that Month
    final firstOfMonth = DateTime(pickedYear.year, pickedMonth);
    final lastOfMonth = DateTime(pickedYear.year, pickedMonth + 1, 0);

    final DateTimeRange? finalRange = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: firstOfMonth, end: lastOfMonth),
      firstDate: firstOfMonth,
      lastDate: lastOfMonth,
      helpText: "Select Day or Week Range",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: LogScreen.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (finalRange != null) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: finalRange.start,
          end: DateTime(
            finalRange.end.year,
            finalRange.end.month,
            finalRange.end.day,
            23,
            59,
            59,
          ),
        );
        _isFiltered = true;
      });
    }
  }

  // Helper to safely get display metrics
  Map<String, dynamic> _getDisplayMetrics(
    String status,
    int timestamp,
    String scheduledTimeStr,
  ) {
    if (status == "Missed")
      return {
        "label": "MISSED",
        "color": LogScreen.statusMissedColor,
        "icon": Icons.cancel,
      };

    if (status == "Taken" && scheduledTimeStr != "--:--") {
      try {
        final actualTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp,
          isUtc: true,
        ).toLocal();
        final format = DateFormat("HH:mm");
        final scheduledDateTime = format.parse(scheduledTimeStr);
        final compareTime = DateTime(
          actualTime.year,
          actualTime.month,
          actualTime.day,
          scheduledDateTime.hour,
          scheduledDateTime.minute,
        );

        if (actualTime.difference(compareTime).inMinutes > 2) {
          return {
            "label": "LATE",
            "color": LogScreen.statusLateColor,
            "icon": Icons.history,
          };
        }
      } catch (e) {
        /* ignore parse errors */
      }
    }
    return {
      "label": "TAKEN",
      "color": LogScreen.primaryColor,
      "icon": Icons.check_circle,
    };
  }

  String _formatTo12Hr(String militaryTime) {
    if (militaryTime == "--:--" || militaryTime.isEmpty) return "--:--";
    try {
      return DateFormat(
        "hh:mm a",
      ).format(DateFormat("HH:mm").parse(militaryTime));
    } catch (e) {
      return militaryTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Medication History",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_isFiltered)
                    IconButton(
                      icon: const Icon(
                        Icons.filter_alt_off,
                        color: Colors.redAccent,
                      ),
                      tooltip: "Clear Filter",
                      onPressed: _resetToDefaultRange,
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.calendar_month,
                      color: _isFiltered
                          ? LogScreen.primaryColor
                          : Colors.black,
                    ),
                    onPressed: _pickDateRange,
                  ),
                ],
              ),
            ),

            if (_selectedRange != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _isFiltered
                      ? "${DateFormat('MMM dd').format(_selectedRange!.start)} - ${DateFormat('MMM dd').format(_selectedRange!.end)}"
                      : "Showing: This Week",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            /// CONTENT
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref("users/${user?.uid}/patients/dominic")
                    .onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(child: Text("Error: ${snapshot.error}"));
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null)
                    return const Center(child: Text("No history found"));

                  final data = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );
                  final logsRaw = Map<dynamic, dynamic>.from(
                    data['logs'] ?? {},
                  );
                  final schedule = Map<dynamic, dynamic>.from(
                    data['schedule'] ?? {},
                  );

                  List<Map<String, dynamic>> logs = [];

                  logsRaw.forEach((dateKey, slots) {
                    if (slots is Map) {
                      final slotMap = Map<dynamic, dynamic>.from(slots);
                      slotMap.forEach((slotName, value) {
                        if (value is Map) {
                          final entry = Map<dynamic, dynamic>.from(value);
                          // FIX: Safely parse the timestamp as an int
                          final rawTs = entry["timestamp"];
                          final int ts = (rawTs is int)
                              ? rawTs
                              : int.tryParse(rawTs?.toString() ?? '0') ?? 0;

                          final date = DateTime.fromMillisecondsSinceEpoch(
                            ts,
                            isUtc: true,
                          ).toLocal();

                          // Null-safe filter check
                          final range = _selectedRange;
                          if (range != null) {
                            /*if (date.isAfter(
                                  range.start.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ) &&
                                date.isBefore(
                                  range.end.add(const Duration(seconds: 1)),
                                ))*/
                            if (!date.isBefore(range.start) &&
                                !date.isAfter(range.end)) {
                              // Safely get schedule time
                              final schedNode = schedule[slotName];
                              final schedTime = (schedNode is Map)
                                  ? (schedNode['time'] ?? "--:--")
                                  : "--:--";

                              logs.add({
                                "slot": slotName,
                                "status": entry["status"] ?? "Unknown",
                                "timestamp": ts,
                                "scheduledTime": schedTime,
                              });
                            }
                          }
                        }
                      });
                    }
                  });

                  if (logs.isEmpty)
                    return const Center(child: Text("No logs for this period"));

                  logs.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

                  final Map<String, List<Map<String, dynamic>>> grouped = {};
                  for (var log in logs) {
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      log["timestamp"],
                      isUtc: true,
                    ).toLocal();

                    final key = DateFormat('EEEE, MMM dd, yyyy').format(date);
                    grouped.putIfAbsent(key, () => []);
                    grouped[key]!.add(log);
                  }

                  final sortedDates = grouped.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedDates[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(dateKey),
                          ...grouped[dateKey]!.map((log) {
                            final metrics = _getDisplayMetrics(
                              log["status"],
                              log["timestamp"],
                              log["scheduledTime"],
                            );
                            final actualTime = DateFormat('hh:mm a').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                log["timestamp"],
                                isUtc: true,
                              ).toLocal(),
                            );

                            return _HistoryCard(
                              time: _formatTo12Hr(log["scheduledTime"]),
                              label: log["slot"],
                              status: metrics["label"],
                              icon: metrics["icon"],
                              color: metrics["color"],
                              subtitle: "Recorded at: $actualTime",
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String time;
  final String label;
  final String status;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _HistoryCard({
    required this.time,
    required this.label,
    required this.status,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "• $label",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
