import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_admin_model.dart';
import '../../services/admin_service.dart';

class AdminStudents extends StatefulWidget {
  const AdminStudents({
    super.key,
  });

  @override
  State<AdminStudents> createState() => _AdminStudentsState();
}

class _AdminStudentsState extends State<AdminStudents> {
  late final AdminService adminService;

  List<StudentAdminModel> students = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    adminService = AdminService(ApiClient());
    loadStudents();
  }

  Future<void> loadStudents() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });

    try {
      final result = await adminService.getStudents();
      if (!mounted) return;
      setState(() {
        students = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });

      showMessage("Unable to load students: $e");
    }
  }

  Future<void> deleteStudent(StudentAdminModel student) async {
    final name = student.name.isNotEmpty ? student.name : student.studentCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Student"),
          content: Text(
            "Permanently delete $name and their fees, payments, attendance, and break records? This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await adminService.deleteStudent(student.id);
      if (!mounted) return;
      showMessage("Student deleted successfully");
      await loadStudents();
    } catch (e) {
      if (!mounted) return;
      showMessage("Unable to delete student: ${ApiError.message(e)}");
    }
  }

  Future<void> resetStudentPassword(StudentAdminModel student) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password for ${student.name}'),
        content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'New password (at least 6 characters)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Reset password'))],
      ),
    );
    controller.dispose();
    if (password == null) return;
    if (password.length < 6) { showMessage('Password must be at least 6 characters'); return; }
    try {
      await adminService.resetAccountPassword('students', student.id, password);
      if (mounted) showMessage('Student password reset successfully');
    } catch (e) {
      if (mounted) {
        showMessage('Unable to reset password: ${ApiError.message(e)}');
      }
    }
  }

  Future<void> editStudent(StudentAdminModel student) async {
    final name = TextEditingController(text: student.name);
    final phone = TextEditingController(text: student.phone ?? '');
    final code = TextEditingController(text: student.studentCode);
    final course = TextEditingController(text: student.course);
    final batch = TextEditingController(text: student.batch ?? '');
    final guardian = TextEditingController(text: student.guardianName ?? '');
    final guardianPhone = TextEditingController(text: student.guardianPhone ?? '');
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Student'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  studentField(controller: name, label: 'Full Name', icon: Icons.person_rounded),
                  studentField(controller: phone, label: 'Phone Number', icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
                  studentField(controller: code, label: 'Student Code', icon: Icons.badge_rounded),
                  studentField(controller: course, label: 'Course / Degree', icon: Icons.school_rounded),
                  studentField(controller: batch, label: 'Batch', icon: Icons.calendar_today_rounded),
                  studentField(controller: guardian, label: 'Guardian Name', icon: Icons.family_restroom_rounded),
                  studentField(controller: guardianPhone, label: 'Guardian Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (name.text.trim().isEmpty || code.text.trim().isEmpty || course.text.trim().isEmpty) {
                  showMessage('Name, student code, and course are required');
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  await adminService.updateStudent(student.id, {
                    'name': name.text.trim(),
                    'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                    'student_code': code.text.trim(),
                    'course': course.text.trim(),
                    'batch': batch.text.trim().isEmpty ? null : batch.text.trim(),
                    'guardian_name': guardian.text.trim().isEmpty ? null : guardian.text.trim(),
                    'guardian_phone': guardianPhone.text.trim().isEmpty ? null : guardianPhone.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  showMessage('Student updated successfully');
                  await loadStudents();
                } catch (e) {
                  if (!mounted) return;
                  setDialogState(() => saving = false);
                  showMessage('Unable to update student: $e');
                }
              },
              child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [name, phone, code, course, batch, guardian, guardianPhone]) {
      controller.dispose();
    }
  }

  Future<void> showAddStudentDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final studentCodeController = TextEditingController();
    final courseController = TextEditingController();
    final batchController = TextEditingController();
    final phoneController = TextEditingController();
    final totalFeesController = TextEditingController();

    bool saving = false;
    bool showPassword = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add New Student"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      studentField(
                        controller: nameController,
                        label: "Full Name",
                        icon: Icons.person_rounded,
                      ),
                      studentField(
                        controller: emailController,
                        label: "Email Address",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      studentField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_rounded,
                        obscure: !showPassword,
                        suffixIcon: IconButton(
                          tooltip: showPassword ? 'Hide password' : 'Show password',
                          onPressed: () => setDialogState(
                            () => showPassword = !showPassword,
                          ),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      studentField(
                        controller: studentCodeController,
                        label: "Student Code (e.g. NOVOX-STU-002)",
                        icon: Icons.badge_rounded,
                      ),
                      studentField(
                        controller: courseController,
                        label: "Course / Degree",
                        icon: Icons.school_rounded,
                      ),
                      studentField(
                        controller: batchController,
                        label: "Batch (e.g. 2025-2027)",
                        icon: Icons.calendar_today_rounded,
                      ),
                      studentField(
                        controller: phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      studentField(
                        controller: totalFeesController,
                        label: "Total Fees (₹, optional)",
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          await handleCreateStudent(
                            dialogContext: dialogContext,
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            studentCode: studentCodeController.text.trim(),
                            course: courseController.text.trim(),
                            batch: batchController.text.trim(),
                            phone: phoneController.text.trim(),
                            totalFees: totalFeesController.text.trim(),
                            setSaving: (v) => setDialogState(() => saving = v),
                          );
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Create Student"),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    studentCodeController.dispose();
    courseController.dispose();
    batchController.dispose();
    phoneController.dispose();
    totalFeesController.dispose();
  }

  Future<void> handleCreateStudent({
    required BuildContext dialogContext,
    required String name,
    required String email,
    required String password,
    required String studentCode,
    required String course,
    required String batch,
    required String phone,
    required String totalFees,
    required void Function(bool) setSaving,
  }) async {
    if (name.isEmpty) {
      showMessage("Please enter full name");
      return;
    }
    if (email.isEmpty) {
      showMessage("Please enter email address");
      return;
    }
    if (password.length < 6) {
      showMessage("Password must be at least 6 characters");
      return;
    }
    if (studentCode.isEmpty) {
      showMessage("Please enter student code");
      return;
    }
    if (course.isEmpty) {
      showMessage("Please enter course");
      return;
    }

    final parsedTotalFees = totalFees.isEmpty ? null : double.tryParse(totalFees);
    if (totalFees.isNotEmpty &&
        (parsedTotalFees == null || parsedTotalFees < 0)) {
      showMessage("Please enter a valid total fee amount");
      return;
    }

    setSaving(true);

    try {
      await adminService.createStudent(
        name: name,
        email: email,
        password: password,
        phone: phone,
        studentCode: studentCode,
        course: course,
        batch: batch,
        totalFees: parsedTotalFees,
      );

      if (!mounted) return;
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Student created successfully"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await loadStudents();
    } catch (e) {
      if (!mounted) return;
      setSaving(false);
      final message = e is DioException
          ? _studentCreateErrorMessage(e)
          : e.toString();
      showMessage("Unable to create student: $message");
    }
  }

  String _studentCreateErrorMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final detail = responseData['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      final message = responseData['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData;
    }
    return error.message ?? 'Request failed. Please try again.';
  }

  Widget studentField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget buildStudentCard(StudentAdminModel student) {
    final firstLetter = student.name.isNotEmpty
        ? student.name[0].toUpperCase()
        : (student.studentCode.isNotEmpty ? student.studentCode[0].toUpperCase() : "S");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          student.studentCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (student.course.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            student.course,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    student.name.isNotEmpty ? student.name : "Student",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (student.batch != null && student.batch!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Batch: ${student.batch}",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (student.totalFees > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      "Total fees: ₹${student.totalFees.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (student.email.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            student.email,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (student.phone != null && student.phone!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          student.phone!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => resetStudentPassword(student),
                        icon: const Icon(Icons.lock_reset_rounded, size: 16),
                        label: const Text('Reset password'),
                      ),
                      TextButton.icon(
                        onPressed: () => deleteStudent(student),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                        label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
              onSelected: (value) async {
                if (value == "edit") {
                  await editStudent(student);
                } else if (value == "delete") {
                  await deleteStudent(student);
                } else if (value == "password") {
                  await resetStudentPassword(student);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "edit",
                  child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppColors.primary), SizedBox(width: 8), Text("Edit Student")]),
                ),
                PopupMenuItem(
                  value: "password",
                  child: Row(children: [Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primary), SizedBox(width: 8), Text("Reset Password")]),
                ),
                const PopupMenuItem(
                  value: "delete",
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text("Delete Student", style: TextStyle(color: AppColors.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            "No Enrolled Students Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            "Tap 'Add Student' below to enroll a new student.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Student Management"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadStudents,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Add Student",
            onPressed: showAddStudentDialog,
            icon: const Icon(Icons.person_add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddStudentDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text("Add Student"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStudents,
              color: AppColors.primary,
              child: students.isEmpty
                  ? buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        return buildStudentCard(students[index]);
                      },
                    ),
            ),
    );
  }
}
