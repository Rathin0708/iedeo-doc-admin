import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String licenseNumber;
  final String specialization;
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;

  AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.licenseNumber,
    required this.specialization,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      role: data['role'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      specialization: data['specialization'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'doctor':
        return 'Doctor';
      case 'therapist':
        return 'Therapist';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  bool get isPending => status.toLowerCase() == 'pending';

  bool get isApproved => status.toLowerCase() == 'approved';

  bool get isRejected => status.toLowerCase() == 'rejected';

  bool get isDoctor => role.toLowerCase() == 'doctor';

  bool get isTherapist => role.toLowerCase() == 'therapist';
}