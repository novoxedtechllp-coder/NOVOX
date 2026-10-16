import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_attendance_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/status_badge.dart';

class AdminAttendance extends StatefulWidget {
  const AdminAttendance({
    super.key,
  });

  @override
  State<AdminAttendance> createState() => _AdminAttendanceState();
}

class _AdminAttendanceState extends State<AdminAttendance> {
  late final AdminService adminService;

  List<AdminAttendanceModel> records = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    adminService = AdminService(ApiClient());
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    try {
      final result = await adminService.getTodayAttendance();

      if (!mounted) return;
      setState(() {
        records = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load attendance: $e"),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String formatDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return "-";
    }

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) {
      return value;
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget attendanceCard(AdminAttendanceModel record) {
    final isLate = record.arrivalStatus.toUpperCase() == "LATE";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLate
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    record.userName.trim().isEmpty
                        ? "?"
                        : record.userName.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${record.userRole[0].toUpperCase()}${record.userRole.substring(1)} · ${record.attendanceStatus.replaceAll("_", " ")}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: record.arrivalStatus),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),

            infoRow(
              Icons.login_rounded,
              "Check-in",
              formatDateTime(record.checkIn),
            ),
            infoRow(
              Icons.logout_rounded,
              "Checkout",
              formatDateTime(record.checkout),
            ),
            infoRow(
              Icons.event_available_rounded,
              "Status",
              record.attendanceStatus.replaceAll("_", " "),
            ),

            if (record.checkInDistance != null)
              infoRow(
                Icons.location_on_rounded,
                "Distance to Perimeter",
                "${record.checkInDistance!.toStringAsFixed(1)} m",
              ),

            if (isLate) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Recorded arrival after scheduled start time",
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final students = records
        .where((record) => record.userRole.toLowerCase() == "student")
        .toList();
    final staff = records
        .where((record) => record.userRole.toLowerCase() == "staff")
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Text("Today's Attendance"),
        bottom: TabBar(
          tabs: [
            Tab(text: "Students (${students.length})"),
            Tab(text: "Staff (${staff.length})"),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: loadAttendance,
          ),
        ],
        ),
        body: TabBarView(
          children: [
            attendanceTab(students, "student"),
            attendanceTab(staff, "staff"),
          ],
        ),
      ),
    );
  }

  Widget attendanceTab(List<AdminAttendanceModel> items, String groupName) {
    final lateCount = items
        .where((record) => record.arrivalStatus.toUpperCase() == "LATE")
        .length;

    return RefreshIndicator(
      onRefresh: loadAttendance,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryValue("$groupName Check-ins", items.length),
                Container(height: 30, width: 1, color: Colors.white24),
                _summaryValue("Late Arrivals", lateCount),
              ],
            ),
          ),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_busy_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No $groupName attendance records today",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map(attendanceCard),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
