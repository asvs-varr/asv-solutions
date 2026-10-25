// BANAAG Payment Submission Model for GCash Verification & Project Top-Ups

class PaymentSubmission {
  final String id;
  final String email;
  final String packageType; // 'BASE_PACK_100' | 'TOPUP_50'
  final String referenceNo;
  final String localReceiptPath;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final DateTime submittedAt;
  final String? approvedVoucherCode;

  PaymentSubmission({
    required this.id,
    required this.email,
    required this.packageType,
    required this.referenceNo,
    required this.localReceiptPath,
    this.status = 'PENDING',
    required this.submittedAt,
    this.approvedVoucherCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'packageType': packageType,
        'referenceNo': referenceNo,
        'localReceiptPath': localReceiptPath,
        'status': status,
        'submittedAt': submittedAt.toIso8601String(),
        if (approvedVoucherCode != null) 'approvedVoucherCode': approvedVoucherCode,
      };

  factory PaymentSubmission.fromJson(Map<String, dynamic> json) => PaymentSubmission(
        id: json['id'] as String,
        email: json['email'] as String,
        packageType: json['packageType'] as String? ?? 'BASE_PACK_100',
        referenceNo: json['referenceNo'] as String? ?? '',
        localReceiptPath: json['localReceiptPath'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '') ?? DateTime.now(),
        approvedVoucherCode: json['approvedVoucherCode'] as String?,
      );

  PaymentSubmission copyWith({
    String? status,
    String? approvedVoucherCode,
  }) {
    return PaymentSubmission(
      id: id,
      email: email,
      packageType: packageType,
      referenceNo: referenceNo,
      localReceiptPath: localReceiptPath,
      status: status ?? this.status,
      submittedAt: submittedAt,
      approvedVoucherCode: approvedVoucherCode ?? this.approvedVoucherCode,
    );
  }
}
