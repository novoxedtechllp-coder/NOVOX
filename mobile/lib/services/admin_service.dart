import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

import '../models/admin_attendance_model.dart';
import '../models/admin_dashboard_model.dart';
import '../models/admin_fee_model.dart';
import '../models/admin_salary_model.dart';
import '../models/geofence_model.dart';
import '../models/staff_admin_model.dart';
import '../models/student_admin_model.dart';

class AdminService {
  final ApiClient apiClient;

  AdminService(this.apiClient);

  // ============================================================
  // ADMIN DASHBOARD
  // ============================================================

  Future<AdminDashboardModel> getDashboard() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminDashboard,
    );

    return AdminDashboardModel.fromJson(
      response.data,
    );
  }

  // ============================================================
  // TODAY ATTENDANCE
  // ============================================================

  Future<List<AdminAttendanceModel>>
      getTodayAttendance() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminAttendance,
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              AdminAttendanceModel.fromJson(item),
        )
        .toList();
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Future<List<StudentAdminModel>>
      getStudents() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminStudents,
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              StudentAdminModel.fromJson(item),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // CREATE STUDENT
  // ------------------------------------------------------------

  Future<StudentAdminModel> createStudent({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String studentCode,
    required String course,
    String? batch,
    String? joiningDate,
    String? guardianName,
    String? guardianPhone,
    double? totalFees,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.adminStudents,
      data: {
        "name": name,
        "email": email,
        "password": password,
        "phone": phone,
        "student_code": studentCode,
        "course": course,
        "batch": batch,
        "joining_date": joiningDate,
        "guardian_name": guardianName,
        "guardian_phone": guardianPhone,
        "total_fees": totalFees,
      },
    );

    return StudentAdminModel.fromJson(
      response.data,
    );
  }

  Future<StudentAdminModel> updateStudent(
    int studentId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.dio.put(
      '${ApiConstants.adminStudents}/$studentId',
      data: data,
    );
    return StudentAdminModel.fromJson(response.data);
  }

  // ------------------------------------------------------------
  // DELETE STUDENT
  // ------------------------------------------------------------

  Future<void> deleteStudent(
    int studentId,
  ) async {
    await apiClient.dio.delete(
      "${ApiConstants.adminStudents}/$studentId",
    );
  }

  Future<void> setAccountActive(String role, int id, bool isActive) async {
    await apiClient.dio.patch(
      '${ApiConstants.adminManagement}/$role/$id/status',
      data: {'is_active': isActive},
    );
  }

  Future<void> resetAccountPassword(String role, int id, String password) async {
    await apiClient.dio.put(
      '${ApiConstants.adminManagement}/$role/$id/password',
      data: {'password': password},
    );
  }

  // ============================================================
  // STAFF
  // ============================================================

  Future<List<StaffAdminModel>>
      getStaff() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminStaff,
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              StaffAdminModel.fromJson(item),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // CREATE STAFF
  // ------------------------------------------------------------

  Future<void> createStaff(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.adminStaff,
      data: data,
    );
  }

  // ------------------------------------------------------------
  // UPDATE STAFF
  // ------------------------------------------------------------

  Future<void> updateStaff(
    int staffId,
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.put(
      "${ApiConstants.adminStaff}/$staffId",
      data: data,
    );
  }

  // ------------------------------------------------------------
  // DEACTIVATE STAFF
  // ------------------------------------------------------------

  Future<void> deactivateStaff(
    int staffId,
  ) async {
    await apiClient.dio.delete(
      "${ApiConstants.adminStaff}/$staffId",
    );
  }

  // ============================================================
  // SALARY
  // ============================================================

  Future<List<AdminSalaryModel>>
      getStaffSalary(
    int staffId,
  ) async {
    final response = await apiClient.dio.get(
      "${ApiConstants.salaryStaff}/$staffId",
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              AdminSalaryModel.fromJson(item),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // CREATE SALARY STRUCTURE
  // ------------------------------------------------------------

  Future<void> createSalaryStructure(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.salaryStructure,
      data: data,
    );
  }

  // ------------------------------------------------------------
  // GENERATE SALARY SLIP
  // ------------------------------------------------------------

  Future<void> generateSalarySlip(
    int staffId,
    int year,
    int month,
  ) async {
    await apiClient.dio.post(
      "${ApiConstants.generateSalarySlip}/$staffId/$year/$month",
    );
  }

  // ============================================================
  // FEES
  // ============================================================

  // ------------------------------------------------------------
  // GET PENDING FEES
  // ------------------------------------------------------------

  Future<List<AdminFeeModel>>
      getPendingFees() async {
    final response = await apiClient.dio.get(
      ApiConstants.pendingFees,
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              AdminFeeModel.fromJson(item),
        )
        .toList();
  }

  Future<List<AdminFeeModel>> getAllStudentFees() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.allStudentFees,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AdminFeeModel.fromJson)
          .toList();
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;

      // Older backend instances may not yet expose /fees/admin/all.
      // The per-student details route already returns paid and unpaid records.
      final students = await getStudents();
      final feeResponses = await Future.wait(
        students.map(
          (student) => apiClient.dio.get(
            '${ApiConstants.feeStudent}/${student.id}',
          ),
        ),
      );
      final records = <AdminFeeModel>[];
      for (var index = 0; index < feeResponses.length; index++) {
        final data = feeResponses[index].data;
        if (data is! List) continue;
        for (final item in data.whereType<Map<String, dynamic>>()) {
          records.add(
            AdminFeeModel.fromJson({
              ...item,
              'student_name': students[index].name,
              'student_code': students[index].studentCode,
              'course': students[index].course,
            }),
          );
        }
      }
      return records;
    }
  }

  Future<void> updateStudentFee(int feeId, double totalAmount) async {
    await apiClient.dio.put(
      '${ApiConstants.studentFee}/$feeId',
      data: {'total_amount': totalAmount},
    );
  }

  // ------------------------------------------------------------
  // CREATE FEE STRUCTURE
  // ------------------------------------------------------------

  Future<void> createFeeStructure(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.feeStructure,
      data: data,
    );
  }

  Future<void> updateFeeStructure(
    int structureId,
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.put(
      '${ApiConstants.feeStructure}/$structureId',
      data: data,
    );
  }

  // ------------------------------------------------------------
  // GET CREATED FEE STRUCTURES
  // ------------------------------------------------------------

  Future<List<dynamic>>
      getFeeStructures() async {
    final response = await apiClient.dio.get(
      ApiConstants.feeStructure,
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return List<dynamic>.from(
      data,
    );
  }

  // ------------------------------------------------------------
  // ASSIGN STUDENT FEE
  // ------------------------------------------------------------

  Future<void> assignStudentFee(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.studentFee,
      data: data,
    );
  }

  // ------------------------------------------------------------
  // RECORD PAYMENT
  // ------------------------------------------------------------

  Future<void> recordPayment(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.feePayment,
      data: data,
    );
  }

  // ------------------------------------------------------------
  // RECEIPT PDF
  // ------------------------------------------------------------

  Future<Response> getReceiptPdf(
    String receiptNumber,
  ) async {
    return await apiClient.dio.get(
      ApiConstants.feeReceiptPdf(
        receiptNumber,
      ),
      options: Options(
        responseType:
            ResponseType.bytes,
      ),
    );
  }

  // ============================================================
  // GEOFENCE
  // ============================================================

  Future<GeofenceModel>
      getGeofence() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminGeofence,
    );

    return GeofenceModel.fromJson(
      response.data,
    );
  }

  // ------------------------------------------------------------
  // CREATE GEOFENCE
  // ------------------------------------------------------------

  Future<void> createGeofence(
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.post(
      ApiConstants.adminGeofence,
      data: data,
    );
  }

  // ------------------------------------------------------------
  // UPDATE GEOFENCE
  // ------------------------------------------------------------

  Future<void> updateGeofence(
    int id,
    Map<String, dynamic> data,
  ) async {
    await apiClient.dio.put(
      "${ApiConstants.adminGeofence}/$id",
      data: data,
    );
  }
}
