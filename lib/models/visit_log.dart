// models/visit_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitLog {
  final String id;
  final String therapistId;
  final String patientId;
  final DateTime visitDate;
  final String notes;
  final double doctorCommissionAmount;
  final double therapistFeeAmount;

  VisitLog(
      {required this.id, required this.therapistId, required this.patientId, required this.visitDate, required this.notes, this.doctorCommissionAmount = 0.0, this.therapistFeeAmount = 0.0});

  factory VisitLog.fromMap(String id, Map<String, dynamic> data) {
    return VisitLog(
      id: id,
      therapistId: data['therapistId'],
      patientId: data['patientId'],
      visitDate: (data['visitDate'] as Timestamp).toDate(),
      notes: data['notes'],
      doctorCommissionAmount: (data['doctorCommissionAmount'] ?? 0).toDouble(),
      therapistFeeAmount: (data['therapistFeeAmount'] ?? 0).toDouble(),
    );
  }
}
