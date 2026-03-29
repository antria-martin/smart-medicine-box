import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const primaryColor = Color(0xFF13EC92);
const navyColor = Color(0xFF1A2B4B);

// Heatmap Score Colors
const Color colorPerfect = Color(0xFF00E676); // All On Time
const Color colorOneLate = Color(0xFFB9F6CA); // 1 Late, 2 On Time
const Color colorTwoLate = Color(0xFFFFD180); // 2 Late, 1 On Time
const Color colorThreeLate = Color(0xFFFFAB40); // 3 Late
const Color colorOneMissed = Color(0xFFFF8A80); // 1 Missed
const Color colorTwoMissed = Color(0xFFD32F2F); // 2 Missed
const Color colorAllMissed = Color(0xFFB71C1C); // 3 Missed
const Color colorNoData = Color(0xFFF1F1F1);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final String uid;
  late final DatabaseReference _logsRef;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    uid = user.uid;
    _logsRef = FirebaseDatabase.instance.ref("users/$uid/patients/dominic");
    _resetToDefaultRange();
  }

  void _resetToDefaultRange() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    setState(() {
      _selectedRange = DateTimeRange(
        start: startOfMonth,
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    });
  }

  // --- LOGIC & INSIGHTS ---

  List<Map<String, dynamic>> _parseLogs(
    Map<dynamic, dynamic> rawData,
    Map<dynamic, dynamic> schedule,
  ) {
    List<Map<String, dynamic>> flatLogs = [];
    final currentRange = _selectedRange;
    if (currentRange == null) return flatLogs;

    rawData.forEach((dateKey, slots) {
      if (slots is Map) {
        slots.forEach((slotName, details) {
          if (details is Map) {
            final dynamic tsValue = details["timestamp"];
            if (tsValue != null && tsValue is int) {
              // 1. Convert Firebase UTC timestamp to Local IST DateTime
              final actualDateTime = DateTime.fromMillisecondsSinceEpoch(
                tsValue,
              );

              // 2. Check if the log falls within the selected calendar range
              bool isWithinRange =
                  actualDateTime.isAfter(
                    currentRange.start.subtract(const Duration(seconds: 1)),
                  ) &&
                  actualDateTime.isBefore(
                    currentRange.end.add(const Duration(seconds: 1)),
                  );

              if (isWithinRange) {
                // 1. Get the status from Firebase (e.g., "Taken")

                String rawStatus = details["status"]?.toString() ?? "Missed";
                String calculatedStatus = "Missed";

                if (rawStatus == "Missed") {
                  calculatedStatus = "Missed";
                } else if (rawStatus == "Taken") {
                  final schedNode = schedule[slotName];
                  final schedTimeStr = (schedNode is Map)
                      ? (schedNode['time'] ?? "--:--")
                      : "--:--";

                  if (schedTimeStr != "--:--") {
                    try {
                      final actualTime = actualDateTime;
                      final format = DateFormat("HH:mm");
                      final scheduledDateTime = format.parse(schedTimeStr);

                      final compareTime = DateTime(
                        actualTime.year,
                        actualTime.month,
                        actualTime.day,
                        scheduledDateTime.hour,
                        scheduledDateTime.minute,
                      );

                      if (actualTime.difference(compareTime).inMinutes > 2) {
                        calculatedStatus = "Late";
                      } else {
                        calculatedStatus = "Taken";
                      }
                    } catch (e) {
                      calculatedStatus = "Taken";
                    }
                  } else {
                    calculatedStatus = "Taken";
                  }
                }

                // 5. Use the calculatedStatus in your map
                flatLogs.add({
                  "date": dateKey,
                  "slot": slotName,
                  "status":
                      calculatedStatus, // <--- Use this instead of rawStatus
                  "timestamp": tsValue,
                  "dateTime": actualDateTime,
                });
              }
            }
          }
        });
      }
    });
    return flatLogs;
  }

  String _generateInsight(List<Map<String, dynamic>> logs, int streak) {
    if (logs.isEmpty) return "Start logging to see personalized care insights.";

    // Use toLowerCase() to match the statuses correctly
    final missed = logs
        .where((l) => l["status"].toString().toLowerCase() == "missed")
        .length;
    final lateCount = logs
        .where((l) => l["status"].toString().toLowerCase() == "late")
        .length;

    if (streak >= 5) {
      return "Excellent! Dominic has maintained a $streak-day perfect streak. Consistency is key to treatment success.";
    }

    if (missed > 3) {
      return "Caution: Multiple missed doses detected. Consider setting earlier phone reminders.";
    }

    if (lateCount > 4) {
      return "Routine Alert: Many doses are 'Late'. The current schedule might not align with Dominic's daily rhythm.";
    }

    return "Stable Routine: Dominic is following the schedule well with minor deviations.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _logsRef.onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("No Data Yet"));
                  }
                  print("SNAPSHOT VALUE:");
                  print(snapshot.data!.snapshot.value);

                  final root = snapshot.data!.snapshot.value;

                  if (root is! Map) {
                    return const Center(child: Text("Invalid Data Format"));
                  }

                  final data = Map<dynamic, dynamic>.from(root);

                  final logsRaw = Map<dynamic, dynamic>.from(
                    data['logs'] ?? {},
                  );
                  final schedule = Map<dynamic, dynamic>.from(
                    data['schedule'] ?? {},
                  );

                  final streak = _calculateCurrentStreak(logsRaw);
                  final filteredLogs = _parseLogs(logsRaw, schedule);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _StreakCounter(streak: streak),
                        const SizedBox(height: 25),
                        _InfoSection(
                          title: "MONTHLY CONSISTENCY",
                          infoText:
                              "This calendar shows daily completion. Green means all doses were taken. Red means at least one was missed.",
                          child: _HeatmapCalendar(
                            logs: filteredLogs,
                            month: _selectedRange!.start,
                            onNextMonth: _nextMonth,
                            onPrevMonth: _prevMonth,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _InfoSection(
                          title: "ROUTINE DRIFT",
                          infoText:
                              "Shows the exact time Morning doses are taken. The arrow indicates if the patient is taking meds earlier or later.",
                          child: _TimeDriftAnalysis(logs: filteredLogs),
                        ),
                        const SizedBox(height: 25),
                        _InfoSection(
                          title: "ADHERENCE BY TIME",
                          infoText:
                              "Compare which time of day has the best compliance rate.",
                          child: _TimeOfDayAnalysis(
                            morning: _slotAdherence(filteredLogs, "Morning"),
                            noon: _slotAdherence(filteredLogs, "Noon"),
                            evening: _slotAdherence(filteredLogs, "Evening"),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _InsightCard(_generateInsight(filteredLogs, streak)),
                        const SizedBox(height: 40),
                        _SummaryCard(filteredLogs),
                        const SizedBox(height: 25),
                      ],
                    ),
                  );
                }, // End of builder
              ), // End of StreamBuilder
            ), // End of Expanded
          ],
        ), // End of Column
      ), // End of SafeArea
    ); // End of Scaffold
  }

  // --- HELPER UI & LOGIC ---

  int _calculateCurrentStreak(Map<dynamic, dynamic> rawData) {
    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      // Check both common formats just in case
      final dateKey = DateFormat('yyyy-MM-dd').format(checkDate);
      final altKey = DateFormat('yyyy-M-d').format(checkDate);

      final dayData = rawData[dateKey] ?? rawData[altKey];

      if (dayData != null && dayData is Map && dayData.isNotEmpty) {
        // A day is successful if all logged slots are either 'Taken' or 'Late'
        // Note: This assumes 3 slots exist. If data is partial, it still counts.
        bool allSuccessful = dayData.values.every((v) {
          final s = v["status"]?.toString().toLowerCase();
          return s == "taken" || s == "late";
        });

        if (allSuccessful) {
          streak++;
        } else {
          break; // Found a Missed dose, stop streak
        }
      } else {
        // If no data for today, keep looking at yesterday.
        // If no data for yesterday, the streak has ended.
        if (i > 0) break;
      }
    }
    return streak;
  }

  double _slotAdherence(List<Map<String, dynamic>> logs, String slot) {
    final sLogs = logs.where((l) => l["slot"] == slot).toList();
    if (sLogs.isEmpty) return 0.0;

    // Here is where we use the logic:
    final successfulDoses = sLogs.where((l) {
      final status = l["status"];
      return status == "Taken" || status == "Late"; // <--- ADDED HERE
    }).length;

    return successfulDoses / sLogs.length;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "Caregiver Insights",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: navyColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: primaryColor),
            onPressed: _pickDateRange,
          ),
        ],
      ),
    );
  }

  // (Date Picker Methods _pickDateRange, _nextMonth, _prevMonth remain identical to previous working code)
  Future<void> _pickDateRange() async {
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

    final firstOfMonth = DateTime(pickedYear.year, pickedMonth);
    final lastOfMonth = DateTime(pickedYear.year, pickedMonth + 1, 0);

    final DateTimeRange? finalRange = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: firstOfMonth, end: lastOfMonth),
      firstDate: firstOfMonth,
      lastDate: lastOfMonth,
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: primaryColor)),
        child: child!,
      ),
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
      });
    }
  }

  void _nextMonth() {
    setState(() {
      DateTime current = _selectedRange!.start;
      DateTime nextMonth = DateTime(current.year, current.month + 1, 1);
      _selectedRange = DateTimeRange(
        start: nextMonth,
        end: DateTime(nextMonth.year, nextMonth.month + 1, 0, 23, 59, 59),
      );
    });
  }

  void _prevMonth() {
    setState(() {
      DateTime current = _selectedRange!.start;
      DateTime prevMonth = DateTime(current.year, current.month - 1, 1);
      _selectedRange = DateTimeRange(
        start: prevMonth,
        end: DateTime(prevMonth.year, prevMonth.month + 1, 0, 23, 59, 59),
      );
    });
  }
}

// --- SUB-COMPONENTS ---

class _InfoSection extends StatelessWidget {
  final String title;
  final String infoText;
  final Widget child;

  const _InfoSection({
    required this.title,
    required this.infoText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(title),
                  content: Text(infoText),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Got it"),
                    ),
                  ],
                ),
              ),
              child: const Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _HeatmapCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final DateTime month;
  final VoidCallback onNextMonth, onPrevMonth;

  const _HeatmapCalendar({
    required this.logs,
    required this.month,
    required this.onNextMonth,
    required this.onPrevMonth,
  });

  Color _calculateColor(List<Map<String, dynamic>> dayLogs) {
    if (dayLogs.isEmpty) return colorNoData;

    // Standardize statuses to lowercase for counting
    int missed = dayLogs
        .where((l) => l["status"].toString().toLowerCase() == "missed")
        .length;
    int late = dayLogs
        .where((l) => l["status"].toString().toLowerCase() == "late")
        .length;

    // 1. If any are missed, use the RED scale
    if (missed >= 3) return colorAllMissed;
    if (missed == 2) return colorTwoMissed;
    if (missed == 1) return colorOneMissed;

    // 2. If none missed, but some are late, use ORANGE/LIGHT GREEN
    if (late == 3) return colorThreeLate; // Solid Orange
    if (late == 2) return colorTwoLate; // Light Orange
    if (late == 1) return colorOneLate; // Light Green (Your Feb 20th case!)

    // 3. Perfect day
    return colorPerfect;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevMonth,
            ),
            Text(
              DateFormat('MMM yyyy').format(month),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextMonth,
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            final dayLogs = logs
                .where((l) => (l["dateTime"] as DateTime).day == index + 1)
                .toList();
            return Container(
              decoration: BoxDecoration(
                color: _calculateColor(dayLogs),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: dayLogs.isEmpty ? Colors.black38 : Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            _LedgerItem(color: colorPerfect, label: "Perfect"),
            _LedgerItem(color: colorOneLate, label: "1 Late"),
            _LedgerItem(color: colorThreeLate, label: "3 Late"),
            _LedgerItem(color: colorOneMissed, label: "1 Miss"),
            _LedgerItem(color: colorTwoMissed, label: "2 Miss"),
            _LedgerItem(color: colorAllMissed, label: "All Miss"),
          ],
        ),
      ],
    );
  }
}

class _LedgerItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LedgerItem({
    required this.color,
    required this.label,
  }); // Fixed trailing semi-colon/bracket here

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _TimeDriftAnalysis extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const _TimeDriftAnalysis({required this.logs});

  @override
  State<_TimeDriftAnalysis> createState() => _TimeDriftAnalysisState();
}

class _TimeDriftAnalysisState extends State<_TimeDriftAnalysis> {
  String selectedSlot = "Morning"; // Default view

  @override
  Widget build(BuildContext context) {
    // Filter logs based on selection and ensure they aren't "Missed"
    final filteredLogs = widget.logs
        .where((l) => l["slot"] == selectedSlot && l["status"] != "Missed")
        .toList();

    // Sort by timestamp to ensure chronological order
    filteredLogs.sort(
      (a, b) => (a["timestamp"] as int).compareTo(b["timestamp"] as int),
    );

    // Calculate Trend
    IconData trendIcon = Icons.trending_flat;
    Color trendColor = Colors.green;

    if (filteredLogs.length >= 2) {
      final last = filteredLogs.last["dateTime"] as DateTime;
      final prev =
          filteredLogs[filteredLogs.length - 2]["dateTime"] as DateTime;

      final int lastMinutes = last.hour * 60 + last.minute;
      final int prevMinutes = prev.hour * 60 + prev.minute;
      final int diff = lastMinutes - prevMinutes;

      if (diff > 5) {
        trendIcon = Icons.trending_up; // Trending Later
        trendColor = Colors.orange;
      } else if (diff < -5) {
        trendIcon = Icons.trending_down; // Trending Earlier
        trendColor = Colors.blue;
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          // Slot Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Morning", "Noon", "Evening"].map((slot) {
              bool isSelected = selectedSlot == slot;
              return GestureDetector(
                onTap: () => setState(() => selectedSlot = slot),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? navyColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 15),

          // Data Row with Trend Arrow
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(trendIcon, color: trendColor, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: filteredLogs.isEmpty
                      ? const Center(
                          child: Text(
                            "No data for this slot",
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              // Inside _TimeDriftAnalysis ListView.builder
                              child: Center(
                                child: Text(
                                  // 'h:mm a' converts to 12-hour format with AM/PM
                                  DateFormat(
                                    'h:mm a',
                                  ).format(filteredLogs[i]["dateTime"]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String text;
  const _InsightCard(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Caregiver Insight",
            style: TextStyle(fontWeight: FontWeight.bold, color: navyColor),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: navyColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// (Remaining Components _StreakCounter, _TimeOfDayAnalysis, _SummaryCard stay similar with minor cleanup)
class _StreakCounter extends StatelessWidget {
  final int streak;
  const _StreakCounter({required this.streak});

  @override
  Widget build(BuildContext context) {
    // Dynamic content based on streak status
    final bool hasStreak = streak > 0;
    final String message = hasStreak
        ? "Keep up the great momentum!"
        : "Log today's doses to start a new streak!";
    final IconData icon = hasStreak
        ? Icons.local_fire_department
        : Icons.shutter_speed_rounded;
    final Color iconColor = hasStreak ? Colors.orange : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: navyColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 40),
          const SizedBox(width: 15),
          Expanded(
            // Added Expanded to handle long text
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStreak ? "$streak Day Streak!" : "No Active Streak",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeOfDayAnalysis extends StatelessWidget {
  final double morning, noon, evening;
  const _TimeOfDayAnalysis({
    required this.morning,
    required this.noon,
    required this.evening,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _bar("Morning", morning),
        _bar("Noon", noon),
        _bar("Evening", evening),
      ],
    );
  }

  Widget _bar(String label, double val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: val,
            color: val < 0.5 ? Colors.redAccent : primaryColor,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(width: 10),
        Text("${(val * 100).toInt()}%", style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  static const primaryColor = Color(0xFF13EC92);

  const _SummaryCard(this.logs);

  @override
  Widget build(BuildContext context) {
    // Helper to count specific statuses
    int count(String status) => logs
        .where(
          (l) => l["status"].toString().toLowerCase() == status.toLowerCase(),
        )
        .length;

    final taken = count("Taken");
    final lateCount = count("Late");
    final missed = count("Missed");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F24), // Dark background to match stats theme
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat("Taken", taken, Colors.white),
          _stat("Late", lateCount, const Color(0xFFFFA500)), // Orange for late
          _stat("Missed", missed, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
