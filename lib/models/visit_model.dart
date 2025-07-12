import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  final String id;
  final String patientId;
  final String therapistId;
  final String therapistName;
  final DateTime visitDate;
  final String? visitTime;
  final String notes;
  final String status;
  final bool followUpRequired;
  final String? vasPainScore;
  final double? amount;
  final String? treatmentPlan;
  final String? progressNotes;
  final String? visitNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VisitModel({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.therapistName,
    required this.visitDate,
    this.visitTime,
    required this.notes,
    required this.status,
    required this.followUpRequired,
    this.vasPainScore,
    this.amount,
    this.treatmentPlan,
    this.progressNotes,
    this.visitNotes,
    required this.createdAt,
    this.updatedAt,
  });

  factory VisitModel.fromMap(String id, Map<String, dynamic> data) {
    return VisitModel(
      id: id,
      patientId: data['patientId'] ?? '',
      therapistId: data['therapistId'] ?? '',
      therapistName: data['therapistName'] ?? '',
      visitDate: (data['visitDate'] as Timestamp).toDate(),
      visitTime: data['visitTime'],
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'completed',
      followUpRequired: data['followUpRequired'] ?? false,
      vasPainScore: data['vasPainScore'],
      amount: data['amount']?.toDouble(),
      treatmentPlan: data['treatmentPlan'],
      progressNotes: data['progressNotes'],
      visitNotes: data['visitNotes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'therapistId': therapistId,
      'therapistName': therapistName,
      'visitDate': visitDate,
      'visitTime': visitTime,
      'notes': notes,
      'status': status,
      'followUpRequired': followUpRequired,
      'vasPainScore': vasPainScore,
      'amount': amount,
      'treatmentPlan': treatmentPlan,
      'progressNotes': progressNotes,
      'visitNotes': visitNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }
}
