import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/download_bytes.dart';
import '../../models/fee_model.dart';
import '../../models/student_payment_model.dart';
import '../../services/fee_service.dart';

class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({super.key});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  late final FeeService feeService;

  List<dynamic> fees = [];
  List<dynamic> payments = [];

  bool loading = true;
  bool paymentsLoading = false;

  @override
  void initState() {
    super.initState();

    feeService = FeeService(ApiClient());

    loadFees();
  }

  // ============================================================
  // LOAD FEES
  // ============================================================

  Future<void> loadFees() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final result = await feeService.getMyFees();

      if (!mounted) return;

      setState(() {
        fees = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage("Unable to load your fee details. Please try again.");
    }
  }

  // ============================================================
  // LOAD PAYMENT HISTORY
  // ============================================================

  Future<void> loadPaymentHistory() async {
    if (paymentsLoading) return;

    setState(() {
      paymentsLoading = true;
    });

    try {
      final result = await feeService.getMyPaymentHistory();

      if (!mounted) return;

      setState(() {
        payments = result;
        paymentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        paymentsLoading = false;
      });

      showMessage("Unable to load payment history. Please try again.");
    }
  }

  // ============================================================
  // RECEIPT
  // ============================================================

  Future<void> downloadReceipt(String receiptNumber) async {
    try {
      final bytes = await feeService.downloadMyReceipt(receiptNumber);
      if (bytes.isEmpty) throw Exception('The receipt file was empty.');
      await downloadBytes(
        bytes,
        filename: '$receiptNumber.pdf',
        contentType: 'application/pdf',
      );

      if (!mounted) return;

      showMessage("Receipt downloaded successfully");
    } catch (e) {
      if (!mounted) return;

      showMessage("Unable to download receipt: $e");
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // SAFE NUMBER
  // ============================================================

  double amount(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // GET FIELD
  // ============================================================

  dynamic field(dynamic item, String key) {
    if (item is Map<String, dynamic>) {
      return item[key];
    }

    // FeeService parses API responses into model instances. Keep supporting
    // those typed values here; treating them as maps silently showed every
    // amount as ₹0.00 and marked empty fees as paid.
    if (item is FeeModel) {
      return switch (key) {
        'id' => item.id,
        'student_id' => item.studentId,
        'total_amount' => item.totalAmount,
        'paid_amount' => item.paidAmount,
        'pending_amount' => item.pendingAmount,
        'status' => item.status,
        _ => null,
      };
    }

    if (item is StudentPaymentModel) {
      return switch (key) {
        'id' => item.id,
        'student_fee_id' => item.studentFeeId,
        'student_id' => item.studentId,
        'amount' => item.amount,
        'payment_method' => item.paymentMethod,
        'transaction_id' => item.transactionId,
        'payment_date' => item.paymentDate,
        'receipt_number' => item.receiptNumber,
        _ => null,
      };
    }

    return null;
  }

  // ============================================================
  // TOTAL FEE
  // ============================================================

  double get totalFee {
    return fees.fold(0, (sum, fee) => sum + amount(field(fee, "total_amount")));
  }

  // ============================================================
  // PAID FEE
  // ============================================================

  double get paidFee {
    return fees.fold(0, (sum, fee) => sum + amount(field(fee, "paid_amount")));
  }

  // ============================================================
  // PENDING FEE
  // ============================================================

  double get pendingFee {
    return fees.fold(
      0,
      (sum, fee) => sum + amount(field(fee, "pending_amount")),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget summaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              "₹${value.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FEE CARD
  // ============================================================

  Widget feeCard(dynamic fee) {
    final total = amount(field(fee, "total_amount"));

    final paid = amount(field(fee, "paid_amount"));

    final pending = amount(field(fee, "pending_amount"));

    final status = (field(fee, "status") ?? "").toString();

    final feeType = (field(fee, "fee_type") ?? "Fee").toString();

    final course = (field(fee, "course") ?? "").toString();

    final isPaid = pending <= 0 || status.toUpperCase() == "PAID";

    final statusColor = isPaid
        ? Colors.green
        : pending < total
        ? Colors.orange
        : Colors.red;

    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    final percentage = total > 0
        ? ((paid / total) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feeType,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (course.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            course,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaid
                        ? "PAID"
                        : status.isNotEmpty
                        ? status
                        : "PENDING",
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 10),

            Row(
              children: [
                amountItem("Total", total),
                amountItem("Paid", paid),
                amountItem("Pending", pending),
              ],
            ),

            const SizedBox(height: 15),

            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(10),
            ),

            const SizedBox(height: 8),

            Text(
              "${percentage.toStringAsFixed(0)}% paid",
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AMOUNT ITEM
  // ============================================================

  Widget amountItem(String title, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            "₹${value.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT HISTORY CARD
  // ============================================================

  Widget paymentCard(dynamic payment) {
    final paymentAmount = amount(field(payment, "amount"));

    final method = (field(payment, "payment_method") ?? "PAYMENT").toString();

    final transactionId = (field(payment, "transaction_id") ?? "").toString();

    final receiptNumber = (field(payment, "receipt_number") ?? "").toString();

    final paymentDate = field(payment, "payment_date");

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "₹${paymentAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        method,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                if (receiptNumber.isNotEmpty)
                  IconButton(
                    tooltip: "Download receipt",
                    onPressed: () => downloadReceipt(receiptNumber),
                    icon: const Icon(Icons.download),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (paymentDate != null)
              _detailRow("Payment Date", formatDate(paymentDate)),

            if (transactionId.isNotEmpty)
              _detailRow("Transaction ID", transactionId),

            if (receiptNumber.isNotEmpty) _detailRow("Receipt", receiptNumber),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDate(dynamic value) {
    if (value == null) {
      return "-";
    }

    try {
      final date = DateTime.parse(value.toString());

      return DateFormat("dd MMM yyyy, hh:mm a").format(date);
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 55, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT HISTORY
  // ============================================================

  void showPaymentHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                "Payment History",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: payments.isEmpty
                    ? emptyState(
                        icon: Icons.history,
                        title: "No payments found",
                        subtitle: "Your payment history will appear here.",
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: payments.map(paymentCard).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Fees"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadFees,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadFees,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "Fee Overview",
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      summaryCard(
                        title: "Total",
                        value: totalFee,
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                      ),
                      summaryCard(
                        title: "Paid",
                        value: paidFee,
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      summaryCard(
                        title: "Pending",
                        value: pendingFee,
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "My Fee Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (fees.isEmpty)
                    emptyState(
                      icon: Icons.receipt_long,
                      title: "No fee records",
                      subtitle: "Your fee information will appear here.",
                    )
                  else
                    ...fees.map(feeCard),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: paymentsLoading
                          ? null
                          : () async {
                              await loadPaymentHistory();

                              if (!mounted) {
                                return;
                              }

                              showPaymentHistory();
                            },
                      icon: const Icon(Icons.history),
                      label: const Text("VIEW PAYMENT HISTORY"),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
