import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConstants {
  // =========================================================
  // BASE URL
  // =========================================================

  static const String _configuredBaseUrl =
      String.fromEnvironment("API_BASE_URL");

  static String get baseUrl {
    // ---------------------------------------------------------
    // 1. Explicit URL passed using --dart-define
    // ---------------------------------------------------------
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    // ---------------------------------------------------------
    // 2. Flutter Web
    // ---------------------------------------------------------
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }

    // ---------------------------------------------------------
    // 3. Physical Android phone on the NOVOX development Wi-Fi.
    // Override with --dart-define=API_BASE_URL=... when the computer's
    // LAN address changes. Android emulators should use 10.0.2.2 instead.
    // ---------------------------------------------------------
    if (Platform.isAndroid) {
      return "http://192.168.29.167:8000";
    }

    // ---------------------------------------------------------
    // 4. Windows desktop / other platforms
    // ---------------------------------------------------------
    return "http://127.0.0.1:8000";
  }

  // =========================================================
  // AUTHENTICATION
  // =========================================================

  static const String login =
      "/auth/login";

  // =========================================================
  // STUDENT
  // =========================================================

  static const String studentDashboard =
      "/student/dashboard";

  static const String myFees =
      "/fees/my-fees";

  static const String myPaymentHistory =
      "/fees/my-payment-history";

  // =========================================================
  // STAFF
  // =========================================================

  static const String staffDashboard =
      "/staff/dashboard";

  static const String staffProfile =
      "/staff/profile";

  static const String staffSalary =
      "/salary/my-slips";

  // =========================================================
  // ADMIN
  // =========================================================

  static const String adminDashboard =
      "/admin/dashboard";

  static const String adminAttendance =
      "/admin/attendance/today";

  static const String adminPendingFees =
      "/admin/fees/pending";

  static const String adminStudents =
      "/admin/management/students";

  static const String adminStaff =
      "/admin/management/staff";

  static const String adminManagement = "/admin/management";

  static const String adminGeofence =
      "/admin/geofence";

  // =========================================================
  // ATTENDANCE
  // =========================================================

  static const String checkIn =
      "/attendance/check-in";

  static const String startBreak =
      "/attendance/break/start";

  static const String endBreak =
      "/attendance/break/end";

  static const String checkout =
      "/attendance/checkout";

  static const String attendanceHistory =
      "/attendance/history";

  // =========================================================
  // FEES
  // =========================================================

  // Create / view fee structures
  static const String feeStructure =
      "/fees/structure";

  // Student fee assignment / management
  static const String studentFee =
      "/fees/student";

  // Payment collection
  static const String feePayment =
      "/fees/payment";

  // Pending fees
  static const String pendingFees =
      "/fees/pending";

  static const String allStudentFees =
      "/fees/admin/all";

  // Student-specific fee details
  static const String feeStudent =
      "/fees/student";

  // Receipt
  static const String feeReceipt =
      "/fees/receipt";

  // Receipt PDF
  static String feeReceiptPdf(
    String receiptNumber,
  ) {
    return "/fees/receipt/$receiptNumber/pdf";
  }

  // =========================================================
  // SALARY
  // =========================================================

  static const String salaryStructure =
      "/salary/structure";

  static const String salaryStaff =
      "/salary/staff";

  static const String generateSalarySlip =
      "/salary/slip";

  // =========================================================
  // REPORTS
  // =========================================================

  static const String reportsSummary =
      "/admin/reports/summary";

  static const String attendanceReport =
      "/admin/reports/attendance";

  static const String lateEntryReport =
      "/admin/reports/late-entry";

  // Admin fee collection report
  static const String feeReport =
      "/admin/reports/fees";

  static const String salaryReport =
      "/admin/reports/salary";

  // =========================================================
  // REPORT EXPORTS
  // =========================================================

  static const String attendancePdfExport =
      "/admin/reports/export/attendance/pdf";

  static const String attendanceCsvExport =
      "/admin/reports/export/attendance/csv";

  static const String feePdfExport =
      "/admin/reports/export/fees/pdf";

  static const String salaryPdfExport =
      "/admin/reports/export/salary/pdf";
}
