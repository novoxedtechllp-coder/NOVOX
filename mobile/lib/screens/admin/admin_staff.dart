import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff_admin_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/status_badge.dart';
import 'admin_salary.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({
    super.key,
  });

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  late final AdminService adminService;

  List<StaffAdminModel> staffList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    adminService = AdminService(ApiClient());
    loadStaff();
  }

  Future<void> loadStaff() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });

    try {
      final data = await adminService.getStaff();
      if (!mounted) return;
      setState(() {
        staffList = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load staff: ${ApiError.message(e)}"),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> deactivateStaff(StaffAdminModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Deactivate Staff"),
        content: Text("Are you sure you want to deactivate ${staff.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Deactivate"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await adminService.deactivateStaff(staff.id);
      if (!mounted) return;
      showMessage("Staff deactivated successfully");
      await loadStaff();
    } catch (e) {
      if (!mounted) return;
      showMessage("Failed to deactivate staff: ${ApiError.message(e)}");
    }
  }

  Future<void> setStaffActive(StaffAdminModel staff, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate Staff'),
          content: Text('Deactivate ${staff.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await adminService.setAccountActive('staff', staff.id, active);
      if (!mounted) return;
      showMessage(active ? 'Staff account activated' : 'Staff account deactivated');
      await loadStaff();
    } catch (e) {
      if (mounted) showMessage('Unable to update account: ${ApiError.message(e)}');
    }
  }

  Future<void> resetStaffPassword(StaffAdminModel staff) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password for ${staff.name}'),
        content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'New password (at least 6 characters)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Reset password'))],
      ),
    );
    controller.dispose();
    if (password == null) return;
    if (password.length < 6) { showMessage('Password must be at least 6 characters'); return; }
    try {
      await adminService.resetAccountPassword('staff', staff.id, password);
      if (mounted) showMessage('Staff password reset successfully');
    } catch (e) { if (mounted) showMessage('Unable to reset password: ${ApiError.message(e)}'); }
  }

  Future<void> showStaffDialog({StaffAdminModel? staff}) async {
    final isEditing = staff != null;

    final nameController = TextEditingController(text: staff?.name ?? "");
    final emailController = TextEditingController(text: staff?.email ?? "");
    final passwordController = TextEditingController();
    final phoneController = TextEditingController(text: staff?.phone ?? "");
    final employeeCodeController = TextEditingController(text: staff?.employeeCode ?? "");
    final designationController = TextEditingController(text: staff?.designation ?? "");
    final departmentController = TextEditingController(text: staff?.department ?? "");
    final joiningDateController = TextEditingController(text: staff?.joiningDate ?? "");

    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? "Edit Faculty / Staff" : "Add Faculty / Staff"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      field(
                        controller: nameController,
                        label: "Full Name",
                        icon: Icons.person_rounded,
                      ),
                      if (!isEditing) ...[
                        field(
                          controller: emailController,
                          label: "Institutional Email",
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        field(
                          controller: passwordController,
                          label: "Password",
                          icon: Icons.lock_rounded,
                          obscure: true,
                        ),
                      ],
                      field(
                        controller: employeeCodeController,
                        label: "Employee Code (e.g. NOVOX-STF-002)",
                        icon: Icons.badge_rounded,
                      ),
                      field(
                        controller: designationController,
                        label: "Designation (e.g. Assistant Professor)",
                        icon: Icons.work_outline_rounded,
                      ),
                      field(
                        controller: departmentController,
                        label: "Department (e.g. Computer Science)",
                        icon: Icons.domain_rounded,
                      ),
                      field(
                        controller: phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      field(
                        controller: joiningDateController,
                        label: "Joining Date (YYYY-MM-DD)",
                        icon: Icons.calendar_today_rounded,
                        readOnly: true,
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            joiningDateController.text = formatDate(selected);
                          }
                        },
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
                          await handleSaveStaff(
                            dialogContext: dialogContext,
                            isEditing: isEditing,
                            staff: staff,
                            nameController: nameController,
                            emailController: emailController,
                            passwordController: passwordController,
                            phoneController: phoneController,
                            employeeCodeController: employeeCodeController,
                            designationController: designationController,
                            departmentController: departmentController,
                            joiningDateController: joiningDateController,
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
                      : Text(isEditing ? "Save Changes" : "Create Staff"),
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
    phoneController.dispose();
    employeeCodeController.dispose();
    designationController.dispose();
    departmentController.dispose();
    joiningDateController.dispose();
  }

  Future<void> handleSaveStaff({
    required BuildContext dialogContext,
    required bool isEditing,
    required StaffAdminModel? staff,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController phoneController,
    required TextEditingController employeeCodeController,
    required TextEditingController designationController,
    required TextEditingController departmentController,
    required TextEditingController joiningDateController,
    required void Function(bool) setSaving,
  }) async {
    final name = nameController.text.trim();
    final employeeCode = employeeCodeController.text.trim();
    final designation = designationController.text.trim();
    final phone = phoneController.text.trim();
    final department = departmentController.text.trim();
    final joiningDate = joiningDateController.text.trim();

    if (name.isEmpty) {
      showMessage("Please enter full name");
      return;
    }
    if (employeeCode.isEmpty) {
      showMessage("Please enter employee code");
      return;
    }
    if (designation.isEmpty) {
      showMessage("Please enter designation");
      return;
    }

    if (!isEditing) {
      if (emailController.text.trim().isEmpty) {
        showMessage("Please enter email address");
        return;
      }
      if (passwordController.text.isEmpty) {
        showMessage("Please enter password");
        return;
      }
    }

    final data = <String, dynamic>{
      "name": name,
      "phone": phone.isEmpty ? null : phone,
      "employee_code": employeeCode,
      "designation": designation,
      "department": department.isEmpty ? null : department,
      "joining_date": joiningDate.isEmpty ? null : joiningDate,
    };

    if (!isEditing) {
      data["email"] = emailController.text.trim();
      data["password"] = passwordController.text;
    }

    setSaving(true);

    try {
      if (isEditing) {
        await adminService.updateStaff(staff!.id, data);
      } else {
        await adminService.createStaff(data);
      }

      if (!mounted) return;
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? "Staff updated successfully" : "Staff created successfully",
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await loadStaff();
    } catch (e) {
      if (!mounted) return;
      setSaving(false);
      showMessage("Failed to save staff: $e");
    }
  }

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
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

  Future<void> openSalary(StaffAdminModel staff) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSalaryScreen(staff: staff),
      ),
    );

    if (!mounted) return;
    await loadStaff();
  }

  Widget buildStaffCard(StaffAdminModel staff) {
    final firstLetter = staff.name.isNotEmpty ? staff.name[0].toUpperCase() : "S";

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
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
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
                          staff.employeeCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: staff.isActive ? "ACTIVE" : "INACTIVE", compact: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    staff.department != null && staff.department!.isNotEmpty
                        ? "${staff.designation} • ${staff.department}"
                        : staff.designation,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (staff.email.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            staff.email,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (staff.phone != null && staff.phone!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          staff.phone!,
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
                        onPressed: () => resetStaffPassword(staff),
                        icon: const Icon(Icons.lock_reset_rounded, size: 16),
                        label: const Text('Reset password'),
                      ),
                      TextButton.icon(
                        onPressed: () => setStaffActive(staff, !staff.isActive),
                        icon: Icon(staff.isActive ? Icons.block_rounded : Icons.check_circle_outline, size: 16),
                        label: Text(staff.isActive ? 'Deactivate' : 'Activate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
              onSelected: (value) async {
                switch (value) {
                  case "salary":
                    await openSalary(staff);
                    break;
                  case "edit":
                    await showStaffDialog(staff: staff);
                    break;
                  case "deactivate":
                      await setStaffActive(staff, false);
                      break;
                    case "activate":
                      await setStaffActive(staff, true);
                      break;
                    case "password":
                      await resetStaffPassword(staff);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "salary",
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text("Manage Salary"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "password",
                  child: Row(children: [Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primary), SizedBox(width: 8), Text("Reset Password")]),
                ),
                const PopupMenuItem(
                  value: "edit",
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text("Edit Profile"),
                    ],
                  ),
                ),
                if (staff.isActive)
                  const PopupMenuItem(
                    value: "deactivate",
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text("Deactivate", style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                if (!staff.isActive)
                  const PopupMenuItem(
                    value: "activate",
                    child: Row(children: [Icon(Icons.check_circle_outline, size: 18, color: AppColors.success), SizedBox(width: 8), Text("Activate Account")]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Faculty & Staff"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadStaff,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Add Staff",
            onPressed: () => showStaffDialog(),
            icon: const Icon(Icons.person_add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStaffDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text("Add Staff"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStaff,
              color: AppColors.primary,
              child: staffList.isEmpty
                  ? ListView(
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
                              Icons.groups_outlined,
                              size: 38,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            "No Faculty or Staff Found",
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
                            "Tap 'Add Staff' to create a new institutional member.",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: staffList.length,
                      itemBuilder: (context, index) {
                        return buildStaffCard(staffList[index]);
                      },
                    ),
            ),
    );
  }
}
