import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPatient {
  final String id;
  final String patientName;
  final int age;
  final String address;
  final String problem;
  final String contactInfo;
  final String preferredTime;
  final String doctorId;
  final String doctorName;
  final String? therapistId;
  final String? therapistName;
  final String status;
  final bool followUpRequired;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final List<String> prescriptionImages;
  final String? name;

  AdminPatient({
    required this.id,
    required this.patientName,
    required this.age,
    required this.address,
    required this.problem,
    required this.contactInfo,
    required this.preferredTime,
    required this.doctorId,
    required this.doctorName,
    this.therapistId,
    this.therapistName,
    required this.status,
    required this.followUpRequired,
    required this.createdAt,
    this.assignedAt,
    this.prescriptionImages = const [],
    this.name,
  });

  factory AdminPatient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminPatient(
      id: doc.id,
      name: data['name'] ?? '',
      patientName: data['patientName'] ?? '',
      age: data['age'] ?? 0,
      address: data['address'] ?? '',
      problem: data['problem'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
      preferredTime: data['preferredTime'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      therapistId: data['therapistId'],
      therapistName: data['therapistName'],
      status: data['status'] ?? 'pending',
      followUpRequired: data['followUpRequired'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      prescriptionImages: List<String>.from(data['prescriptionImages'] ?? []),
    );
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Unassigned';
      case 'assigned':
        return 'Assigned';
      case 'visited':
        return 'Visited';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  bool get isUnassigned => therapistId == null || therapistId!.isEmpty;

  bool get isAssigned => therapistId != null && therapistId!.isNotEmpty;

  bool get isPending => status.toLowerCase() == 'pending';

  bool get needsFollowUp => followUpRequired;

  String get assignmentStatus {
    if (isUnassigned) {
      return 'Waiting for assignment';
    } else {
      return 'Assigned to $therapistName';
    }
  }
}