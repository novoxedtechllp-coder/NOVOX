import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_attendance_model.dart';
import '../../models/admin_dashboard_model.dart';
import '../../services/admin_service.dart';
import '../../services/admin_websocket_service.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/responsive_grid.dart';
import '../../widgets/section_heading.dart';
import '../../widgets/status_badge.dart';

import 'admin_attendance.dart';
import 'admin_fees.dart';
import 'admin_geofence.dart';
import 'admin_reports_screen.dart';
import 'admin_staff.dart';
import 'admin_students.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final AdminService adminService;
  final AdminWebSocketService webSocketService = AdminWebSocketService();

  AdminDashboardModel? dashboard;
  List<AdminAttendanceModel> attendance = [];

  bool loading = true;
  bool refreshing = false;
  bool wsConnected = false;

  StreamSubscription<Map<String, dynamic>>? webSocketSubscription;
  Timer? reconnectTimer;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    adminService = AdminService(ApiClient());
    loadDashboard();
    connectWebSocket();
  }

  Future<void> loadDashboard() async {
    try {
      final summary = await adminService.getDashboard();
      final todayAttendance = await adminService.getTodayAttendance();

      if (!mounted) return;

      setState(() {
        dashboard = summary;
        attendance = todayAttendance;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        refreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load dashboard: $e"),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> refreshDashboard() async {
    if (refreshing) return;
    if (!mounted) return;

    setState(() {
      refreshing = true;
    });

    await loadDashboard();
  }

  Future<void> connectWebSocket() async {
    if (disposed) return;
    await webSocketSubscription?.cancel();

    try {
      final stream = await webSocketService.connect();
      if (disposed || !mounted) return;

      setState(() {
        wsConnected = true;
      });

      webSocketSubscription = stream.listen(
        (event) {
          if (!mounted) return;
          final type = event["type"]?.toString();

          if (type == "attendance_checked_in" ||
              type == "attendance_checked_out" ||
              type == "attendance_break_started" ||
              type == "attendance_break_ended" ||
              type == "attendance_updated" ||
              type == "dashboard_refresh") {
            loadDashboard();
          }
        },
        onError: (err) {
          if (disposed || !mounted) return;
          setState(() {
            wsConnected = false;
          });
          scheduleReconnect();
        },
        onDone: () {
          if (disposed || !mounted) return;
          setState(() {
            wsConnected = false;
          });
          scheduleReconnect();
        },
      );
    } catch (_) {
      if (disposed || !mounted) return;
      setState(() {
        wsConnected = false;
      });
      scheduleReconnect();
    }
  }

  void scheduleReconnect() {
    if (disposed) return;
    reconnectTimer?.cancel();
    reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!disposed && mounted) {
        connectWebSocket();
      }
    });
  }

  Future<void> handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out of NOVOX Admin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SecureStorage.clear();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  void openAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAttendance()),
    );
  }

  void openStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStudents()),
    );
  }

  void openStaff() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStaffScreen()),
    );
  }

  void openFees() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminFeesScreen()),
    );
  }

  void openGeofence() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminGeofenceScreen()),
    );
  }

  void openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
    );
  }

  Widget _buildLivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: wsConnected
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: wsConnected
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: wsConnected ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            wsConnected ? "LIVE" : "SYNCING",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: wsConnected ? AppColors.success : AppColors.warning,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHeader() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -92,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 32,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'ADMINISTRATOR PORTAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      "NOVOX Administrator",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Campus Operations & Analytics",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111D38),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(AdminAttendanceModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySoft,
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${item.userRole.toUpperCase()}  •  In: ${item.checkIn ?? '-'}  •  Out: ${item.checkout ?? '-'}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: item.arrivalStatus, compact: true),
                if (item.checkInDistance != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    "${item.checkInDistance!.toStringAsFixed(0)}m",
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceGroup(
    String title,
    List<AdminAttendanceModel> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            "$title (${items.length})",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "No $title attendance today",
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          )
        else
          ...items.take(4).map(_buildAttendanceItem),
      ],
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

    if (dashboard == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("NOVOX Admin"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: handleLogout,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 54,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                "Unable to connect to dashboard",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: refreshDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
              ),
            ],
          ),
        ),
      );
    }

    final studentAttendance = attendance
        .where((item) => item.userRole.toLowerCase() == "student")
        .toList();
    final staffAttendance = attendance
        .where((item) => item.userRole.toLowerCase() == "staff")
        .toList();

    final data = dashboard!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("NOVOX Admin"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildLivePill(),
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: refreshDashboard,
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.danger,
            onPressed: handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshDashboard,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Admin Hero Card
            _buildAdminHeader(),

            const SizedBox(height: 24),

            // Section Title
            const SectionHeading(
              title: "Institutional Overview",
              subtitle: "A live snapshot of campus activity",
            ),

            const SizedBox(height: 14),

            // Metric Cards
            ResponsiveGrid(
              children: [
            DashboardCard(
              title: "Total Students",
              value: data.totalStudents.toString(),
              subtitle: "Enrolled in active courses",
              icon: Icons.school_rounded,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primarySoft,
              onTap: openStudents,
            ),

            DashboardCard(
              title: "Total Faculty & Staff",
              value: data.totalStaff.toString(),
              subtitle: "Active department members",
              icon: Icons.groups_rounded,
              iconColor: AppColors.primaryLight,
              iconBgColor: AppColors.primarySoft,
              onTap: openStaff,
            ),

            DashboardCard(
              title: "Present Today",
              value: data.presentToday.toString(),
              subtitle: "Checked in on campus",
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.success,
              iconBgColor: AppColors.successBg,
              onTap: openAttendance,
            ),

            DashboardCard(
              title: "Late Arrivals",
              value: data.lateToday.toString(),
              subtitle: "Marked after threshold",
              icon: Icons.schedule_rounded,
              iconColor: AppColors.warning,
              iconBgColor: AppColors.warningBg,
              onTap: openAttendance,
            ),

            DashboardCard(
              title: "Total Pending Fees",
              value: "₹ ${data.totalPendingAmount.toStringAsFixed(2)}",
              subtitle: "${data.pendingFeeStudents} student(s) with dues",
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.danger,
              iconBgColor: AppColors.dangerBg,
              onTap: openFees,
            ),
              ],
            ),

            const SizedBox(height: 24),

            // Management Section
            const Text(
              "Management Hub",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 14),

            ResponsiveGrid(
              minItemWidth: 320,
              children: [
            _buildManagementTile(
              title: "Students Management",
              subtitle: "Enrollment, course assignments & directories",
              icon: Icons.school_outlined,
              iconColor: AppColors.primary,
              onTap: openStudents,
            ),

            _buildManagementTile(
              title: "Staff & Faculty",
              subtitle: "Designations, departments & salary setups",
              icon: Icons.badge_outlined,
              iconColor: AppColors.primaryLight,
              onTap: openStaff,
            ),

            _buildManagementTile(
              title: "Fee Management",
              subtitle: "Fee structures, pending dues & collection",
              icon: Icons.payment_outlined,
              iconColor: const Color(0xFF0D9488),
              onTap: openFees,
            ),

            _buildManagementTile(
              title: "Campus Geofence Settings",
              subtitle: "GPS perimeter coordinates & radius controls",
              icon: Icons.radar_rounded,
              iconColor: const Color(0xFF7C3AED),
              onTap: openGeofence,
            ),

            _buildManagementTile(
              title: "Reports & Analytics",
              subtitle: "Attendance, late entries, salary & fee summaries",
              icon: Icons.analytics_outlined,
              iconColor: const Color(0xFFEA580C),
              onTap: openReports,
            ),
              ],
            ),

            const SizedBox(height: 26),

            // Today's Live Attendance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Attendance",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                TextButton(
                  onPressed: openAttendance,
                  child: const Text("View All"),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (attendance.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    "No attendance activity recorded today",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else ...[
              _buildAttendanceGroup("Students", studentAttendance),
              const SizedBox(height: 8),
              _buildAttendanceGroup("Staff", staffAttendance),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposed = true;
    reconnectTimer?.cancel();
    webSocketSubscription?.cancel();
    webSocketService.disconnect();
    super.dispose();
  }
}
