import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({
    super.key,
  });

  @override
  State<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState
    extends State<StaffAttendanceScreen> {
  late final AttendanceService attendanceService;

  List<AttendanceModel> attendance = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    attendanceService = AttendanceService(
      ApiClient(),
    );

    loadAttendance();
  }

  // ============================================================
  // LOAD ATTENDANCE
  // ============================================================

  Future<void> loadAttendance() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data =
          await attendanceService.getHistory();

      if (!mounted) return;

      setState(() {
        attendance = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        "Failed to load attendance: ${ApiError.message(e)}",
      );
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return "-";
    }

    try {
      final parsed = DateTime.parse(date);

      return DateFormat(
        "dd MMM yyyy",
      ).format(parsed);
    } catch (_) {
      return date;
    }
  }

  // ============================================================
  // DATE TIME
  // ============================================================

  String formatDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return "-";
    }

    try {
      final parsed = DateTime.parse(value);

      return DateFormat(
        "hh:mm a",
      ).format(parsed.toLocal());
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case "PRESENT":
        return Colors.green;

      case "LATE":
      case "LATE_ENTRY":
        return Colors.orange;

      case "ABSENT":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String statusLabel(String status) {
    switch (status.toUpperCase()) {
      case "LATE_ENTRY":
        return "LATE";

      case "PRESENT":
        return "PRESENT";

      case "ABSENT":
        return "ABSENT";

      default:
        return status;
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget infoItem(
    String title,
    String value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE CARD
  // ============================================================

  Widget attendanceCard(
    AttendanceModel item,
  ) {
    final status = item.attendanceStatus;
    final color = statusColor(status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: const Icon(
                    Icons.calendar_today,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDate(
                          item.attendanceDate,
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Check-in: "
                        "${formatDateTime(item.checkIn)}",
                      ),

                      Text(
                        "Checkout: "
                        "${formatDateTime(item.checkout)}",
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            Row(
              children: [
                infoItem(
                  "Arrival",
                  item.arrivalStatus,
                ),

                infoItem(
                  "Break",
                  formatMinutes(item.totalBreakMinutes),
                ),

                infoItem(
                  "Work",
                  item.totalWorkMinutes != null
                      ? formatMinutes(item.totalWorkMinutes!)
                      : "No checkout",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  String formatMinutes(int minutes) =>
      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

  Widget emptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),

        Icon(
          Icons.event_available_outlined,
          size: 60,
          color: AppColors.textMuted,
        ),

        const SizedBox(height: 12),

        const Center(
          child: Text(
            "No attendance records found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 6),

        Center(
          child: Text(
            "Your attendance history "
            "will appear here.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Attendance",
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadAttendance,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadAttendance,
              child: attendance.isEmpty
                  ? emptyState()
                  : ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(16),
                      itemCount:
                          attendance.length,
                      itemBuilder:
                          (context, index) {
                        return attendanceCard(
                          attendance[index],
                        );
                      },
                    ),
            ),
    );
  }
}
