import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../widgets/status_badge.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({
    super.key,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends State<StudentAttendanceScreen> {
  late final AttendanceService attendanceService;

  List<AttendanceModel> history = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    attendanceService = AttendanceService(
      ApiClient(),
    );

    loadHistory();
  }

  // ============================================================
  // LOAD ATTENDANCE HISTORY
  // ============================================================

  Future<void> loadHistory() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final result =
          await attendanceService.getHistory();

      if (!mounted) return;

      setState(() {
        history = result;
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
            "Unable to load attendance: ${ApiError.message(e)}",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // ATTENDANCE CARD
  // ============================================================

  Widget buildAttendanceCard(
    AttendanceModel item,
  ) {
    final status =
        item.attendanceStatus.toUpperCase();

    final arrivalStatus =
        item.arrivalStatus.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ----------------------------------------------------
            // DATE + STATUS
            // ----------------------------------------------------
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.attendanceDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        arrivalStatus.isEmpty
                            ? "Arrival status unavailable"
                            : arrivalStatus,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: status.isEmpty ? "UNKNOWN" : status,
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 14),

            // ----------------------------------------------------
            // CHECK-IN / CHECKOUT
            // ----------------------------------------------------
            Row(
              children: [
                buildInfo(
                  icon: Icons.login_rounded,
                  title: "Check-in",
                  value: item.checkIn ?? "-",
                ),
                buildInfo(
                  icon: Icons.logout_rounded,
                  title: "Checkout",
                  value: item.checkout ?? "-",
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // BREAK / WORK
            // ----------------------------------------------------
            Row(
              children: [
                buildInfo(
                  icon: Icons.coffee_rounded,
                  title: "Break",
                  value: formatMinutes(item.totalBreakMinutes),
                ),
                buildInfo(
                  icon: Icons.schedule_rounded,
                  title: "Work",
                  value: item.totalWorkMinutes != null
                      ? formatMinutes(item.totalWorkMinutes!)
                      : "-",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFORMATION ITEM
  // ============================================================

  String formatMinutes(int minutes) =>
      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

  Widget buildInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.30,
        ),
        Icon(
          Icons.event_busy_outlined,
          size: 70,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            "No attendance records",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "Your attendance history will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
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
          "Attendance History",
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadHistory,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : history.isEmpty
              ? RefreshIndicator(
                  onRefresh: loadHistory,
                  child: buildEmptyState(),
                )
              : RefreshIndicator(
                  onRefresh: loadHistory,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      return buildAttendanceCard(
                        history[index],
                      );
                    },
                  ),
                ),
    );
  }
}
