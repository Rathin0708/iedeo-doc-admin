import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';

class TherapistAssignedPatientsScreen extends StatelessWidget {
  final String therapistId;
  final String therapistName;

  const TherapistAssignedPatientsScreen({
    Key? key,
    required this.therapistId,
    required this.therapistName
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access allPatients via Provider (already up-to-date in app memory)
    final allPatients = Provider
        .of<AdminFirebaseService>(context, listen: false)
        .allPatients;
    final assignedPatients = allPatients.where((p) =>
    p.therapistId == therapistId).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Assigned Patients for $therapistName')),
      body: assignedPatients.isEmpty
          ? Center(child: Text('No patients assigned to $therapistName'))
          : ListView.builder(
        itemCount: assignedPatients.length,
        itemBuilder: (context, index) {
          final patient = assignedPatients[index];
          return Card(
            child: ListTile(
              title: Text(patient.patientName),
              subtitle: Text('Contact: ${patient.contactInfo ?? ''}'),
            ),
          );
        },
      ),
    );
  }
}
