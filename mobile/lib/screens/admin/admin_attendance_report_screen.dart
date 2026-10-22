import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../services/report_service.dart';

class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({
    super.key,
  });

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen> {
  late final ReportService reportService;

  List<dynamic> records = [];

  DateTime? startDate;
  DateTime? endDate;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    reportService = ReportService(
      ApiClient(),
    );

    loadReport();
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> loadReport() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await reportService.getAttendanceReport(
        startDate: startDate == null
            ? null
            : formatDate(startDate!),
        endDate: endDate == null
            ? null
            : formatDate(endDate!),
      );

      if (!mounted) return;

      setState(() {
        records = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load attendance report: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // START DATE
  // ============================================================

  Future<void> selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    setState(() {
      startDate = selected;
    });

    await loadReport();
  }

  // ============================================================
  // END DATE
  // ============================================================

  Future<void> selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    setState(() {
      endDate = selected;
    });

    await loadReport();
  }

  // ============================================================
  // CLEAR FILTER
  // ============================================================

  Future<void> clearFilters() async {
    setState(() {
      startDate = null;
      endDate = null;
    });

    await loadReport();
  }

  // ============================================================
  // DISPLAY DATE
  // ============================================================

  String displayDate(String? value) {
    if (value == null || value.isEmpty) {
      return "-";
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // ============================================================
  // DISPLAY TIME
  // ============================================================

  String displayTime(String? value) {
    if (value == null || value.isEmpty) {
      return "-";
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return "$hour:$minute";
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget statusChip(String value) {
    Color backgroundColor;
    Color textColor;

    switch (value.toUpperCase()) {
      case "ON_TIME":
        backgroundColor = AppColors.successBg;
        textColor = AppColors.success;
        break;

      case "LATE":
        backgroundColor = AppColors.warningBg;
        textColor = AppColors.warning;
        break;

      case "PRESENT":
        backgroundColor = AppColors.infoBg;
        textColor = AppColors.info;
        break;

      default:
        backgroundColor = AppColors.surfaceVariant;
        textColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value.replaceAll("_", " "),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // INFORMATION ITEM
  // ============================================================

  Widget _info(
    String title,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
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
    );
  }

  // ============================================================
  // ATTENDANCE CARD
  // ============================================================

  Widget attendanceCard(
    Map<String, dynamic> item,
  ) {
    final name =
        item["user_name"]?.toString() ?? "-";

    final date =
        item["attendance_date"]?.toString();

    final checkIn =
        item["check_in"]?.toString();

    final checkout =
        item["checkout"]?.toString();

    final status =
        item["attendance_status"]?.toString() ?? "-";

    final arrival =
        item["arrival_status"]?.toString() ?? "-";

    final breakMinutes =
        item["total_break_minutes"] ?? 0;

    final workMinutes = item["total_work_minutes"];

    final distance =
        item["check_in_distance"];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // USER
            // --------------------------------------------------

            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : "?",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayDate(date),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                statusChip(arrival),
              ],
            ),

            const Divider(height: 28),

            // --------------------------------------------------
            // CHECK IN / CHECKOUT
            // --------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _info(
                    "Check In",
                    displayTime(checkIn),
                  ),
                ),
                Expanded(
                  child: _info(
                    "Checkout",
                    displayTime(checkout),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // BREAK / WORK
            // --------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _info(
                    "Break",
                    "$breakMinutes min",
                  ),
                ),
                Expanded(
                  child: _info(
                    "Work",
                    workMinutes == null ? "No checkout" : "$workMinutes min",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // DISTANCE
            // --------------------------------------------------

            if (distance != null)
              _info(
                "Check-in Distance",
                "${distance.toString()} m",
              ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // ATTENDANCE STATUS
            // --------------------------------------------------

            Row(
              children: [
                const Text(
                  "Status: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status.replaceAll("_", " "),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          "Attendance Report",
        ),
        actions: [
          if (startDate != null || endDate != null)
            IconButton(
              tooltip: "Clear Filters",
              icon: const Icon(
                Icons.filter_alt_off,
              ),
              onPressed: clearFilters,
            ),

          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: loadReport,
          ),
        ],
      ),

      body: Column(
        children: [
          // ====================================================
          // DATE FILTERS
          // ====================================================

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selectStartDate,
                    icon: const Icon(
                      Icons.calendar_month,
                    ),
                    label: Text(
                      startDate == null
                          ? "Start Date"
                          : formatDate(startDate!),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selectEndDate,
                    icon: const Icon(
                      Icons.calendar_month,
                    ),
                    label: Text(
                      endDate == null
                          ? "End Date"
                          : formatDate(endDate!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // LOADING
          // ====================================================

          if (loading)
            const LinearProgressIndicator(),

          // ====================================================
          // RECORDS
          // ====================================================

          Expanded(
            child: records.isEmpty && !loading
                ? RefreshIndicator(
                    onRefresh: loadReport,
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(
                          child: Text(
                            "No attendance records found",
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadReport,
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.all(12),
                      itemCount: records.length,
                      itemBuilder:
                          (context, index) {
                        return attendanceCard(
                          Map<String, dynamic>.from(
                            records[index],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
