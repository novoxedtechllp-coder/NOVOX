class StudentProfileModel {
  final int? id;
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final String? studentCode;
  final String? course;
  final String? batch;
  final String? joiningDate;
  final String? guardianName;
  final String? guardianPhone;

  const StudentProfileModel({
    this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.studentCode,
    this.course,
    this.batch,
    this.joiningDate,
    this.guardianName,
    this.guardianPhone,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      id: _toNullableInt(json['id']),
      userId: _toInt(json['user_id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: _toNullableString(json['phone']),
      studentCode: _toNullableString(json['student_code']),
      course: _toNullableString(json['course']),
      batch: _toNullableString(json['batch']),
      joiningDate: _toNullableString(json['joining_date']),
      guardianName: _toNullableString(json['guardian_name']),
      guardianPhone: _toNullableString(json['guardian_phone']),
    );
  }

  static int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _toNullableInt(dynamic value) =>
      value == null ? null : int.tryParse(value.toString());

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
