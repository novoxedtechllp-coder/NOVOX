import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/fee_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/section_heading.dart';
import '../../widgets/responsive_grid.dart';

import 'student_attendance.dart';
import 'student_fees.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late final AttendanceService attendanceService;
  late final FeeService feeService;

  AttendanceModel? todayAttendance;
  List<dynamic> fees = [];

  bool loading = true;
  bool actionLoading = false;
  Timer? attendanceTicker;
  bool refreshingForNewDay = false;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    attendanceService = AttendanceService(apiClient);
    feeService = FeeService(apiClient);
    attendanceTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final record = todayAttendance;
      final now = DateTime.now();
      final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (record != null && record.attendanceDate != today && !refreshingForNewDay) {
        refreshingForNewDay = true;
        setState(() => todayAttendance = null);
        loadDashboard().whenComplete(() => refreshingForNewDay = false);
        return;
      }
      if (mounted && todayAttendance?.checkIn != null && todayAttendance?.checkout == null) {
        setState(() {});
      }
    });
    loadDashboard();
  }

  @override
  void dispose() {
    attendanceTicker?.cancel();
    super.dispose();
  }

  Duration workedToday() {
    final record = todayAttendance;
    if (record == null) return Duration.zero;
    if (record.checkout != null && record.totalWorkMinutes != null) {
      return Duration(minutes: record.totalWorkMinutes!);
    }
    if (record.checkIn == null) return Duration.zero;
    try {
      var elapsed = DateTime.now().difference(DateTime.parse(record.checkIn!));
      elapsed -= Duration(minutes: record.totalBreakMinutes);
      if (record.activeBreak && record.currentBreakStart != null) {
        elapsed -= DateTime.now().difference(DateTime.parse(record.currentBreakStart!));
      }
      return elapsed.isNegative ? Duration.zero : elapsed;
    } catch (_) {
      return Duration(minutes: record.totalWorkMinutes ?? 0);
    }
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  Duration breakTimeToday() {
    final record = todayAttendance;
    if (record == null) return Duration.zero;
    var duration = Duration(minutes: record.totalBreakMinutes);
    if (record.activeBreak && record.currentBreakStart != null) {
      try { duration += DateTime.now().difference(DateTime.parse(record.currentBreakStart!)); } catch (_) {}
    }
    return duration;
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });

    try {
      final attendance = await attendanceService.getToday();
      final studentFees = await feeService.getMyFees();

      if (!mounted) return;
      setState(() {
        todayAttendance = attendance;
        fees = studentFees;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });

      showMessage("Failed to load dashboard: $e");
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showMessage("Please enable GPS/location services on your device.");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage("Location permission is required for campus attendance.");
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      showMessage("Unable to get current location: $e");
      return null;
    }
  }

  Future<void> checkIn() async {
    if (actionLoading) return;
    setState(() {
      actionLoading = true;
    });

    try {
      final position = await getCurrentLocation();
      if (position == null) {
        return;
      }

      await attendanceService.checkIn(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      showMessage("Check-in recorded successfully.");
      await loadDashboard();
    } catch (e) {
      if (!mounted) return;
      showMessage("Check-in failed: ${ApiError.message(e)}");
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> startBreak() async {
    if (actionLoading) return;
    setState(() {
      actionLoading = true;
    });

    try {
      await attendanceService.startBreak();
      if (!mounted) return;
      showMessage("Break started.");
      await loadDashboard();
    } catch (e) {
      if (!mounted) return;
      showMessage("Unable to start break: $e");
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> endBreak() async {
    if (actionLoading) return;
    setState(() {
      actionLoading = true;
    });

    try {
      await attendanceService.endBreak();
      if (!mounted) return;
      showMessage("Break ended.");
      await loadDashboard();
    } catch (e) {
      if (!mounted) return;
      showMessage("Unable to end break: $e");
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> checkout() async {
    if (actionLoading) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Checkout Confirmation"),
          content: const Text(
            "Are you sure you want to checkout for today? This will conclude your campus attendance.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Checkout"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      actionLoading = true;
    });

    try {
      final position = await getCurrentLocation();
      if (position == null) {
        return;
      }

      await attendanceService.checkout(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      showMessage("Checkout recorded successfully.");
      await loadDashboard();
    } catch (e) {
      if (!mounted) return;
      showMessage("Checkout failed: ${ApiError.message(e)}");
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out of NOVOX Student?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String arrivalLabel() {
    final arrival = todayAttendance?.arrivalStatus ?? "";
    if (arrival.isEmpty) return "Not checked in";
    if (arrival.toUpperCase() == "ON_TIME") return "On Time";
    if (arrival.toUpperCase() == "LATE" || arrival.toUpperCase() == "LATE_ENTRY") {
      return "Late Entry";
    }
    return arrival;
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.heroGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome to NOVOX",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Student Portal • Academic Year",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAttendanceCard() {
    final status = todayAttendance?.attendanceStatus ?? "NOT_MARKED";
    final checkedIn = todayAttendance != null;
    final checkedOut = todayAttendance?.checkout != null;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardBorder,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Today's Attendance",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              buildInfo(
                "Arrival Status",
                arrivalLabel(),
                Icons.access_time_rounded,
                AppColors.primary,
              ),
              buildInfo(
                "Break Time",
                formatDuration(breakTimeToday()),
                Icons.coffee_rounded,
                AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(children: [buildInfo("Worked Today", formatDuration(workedToday()), Icons.schedule_rounded, AppColors.success)]),

          const SizedBox(height: 16),

          Row(
            children: [
              buildInfo(
                "Check-in",
                todayAttendance?.checkIn ?? "-",
                Icons.login_rounded,
                AppColors.primaryLight,
              ),
              buildInfo(
                "Checkout",
                todayAttendance?.checkout ?? "-",
                Icons.logout_rounded,
                AppColors.success,
              ),
            ],
          ),

          if (todayAttendance?.checkInDistance != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  "Geofence distance: ${todayAttendance!.checkInDistance!.toStringAsFixed(0)}m",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          if (!checkedIn)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: actionLoading ? null : checkIn,
                icon: actionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.location_on_rounded, size: 20),
                label: const Text(
                  "CHECK IN NOW",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

          if (checkedIn && !checkedOut) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionLoading || (todayAttendance?.activeBreak ?? false) ? null : startBreak,
                    icon: const Icon(Icons.coffee_rounded, size: 18),
                    label: const Text("Start Break"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionLoading || !(todayAttendance?.activeBreak ?? false) ? null : endBreak,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text("End Break"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: actionLoading || (todayAttendance?.activeBreak ?? false) ? null : checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  "CHECKOUT",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          if (checkedOut)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Campus attendance concluded for today.",
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildInfo(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

  Widget buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: iconColor.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFeesCard() {
    return buildMenuCard(
      title: "My Academic Fees",
      subtitle: fees.isEmpty
          ? "No fee schedules recorded"
          : "${fees.length} fee schedule(s) • View payments & receipts",
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xFF0D9488),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentFeesScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("NOVOX Student"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loading ? null : loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.danger,
            onPressed: handleLogout,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadDashboard,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  buildHeader(),
                  buildAttendanceCard(),
                  const SizedBox(height: 24),
                  const SectionHeading(
                    title: "Quick Access",
                    subtitle: "Your attendance and fee records",
                  ),
                  const SizedBox(height: 12),
                  ResponsiveGrid(
                    minItemWidth: 320,
                    children: [
                  buildMenuCard(
                    title: "Attendance History",
                    subtitle: "Daily logs, check-in timestamps & work hours",
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentAttendanceScreen(),
                        ),
                      );
                    },
                  ),
                  buildFeesCard(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
