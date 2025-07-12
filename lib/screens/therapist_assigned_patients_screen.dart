import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';
import 'patient_visit_logs_screen.dart';

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
          // Make the card tappable to show visit logs
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PatientVisitLogsScreen(
                          patientId: patient.id,
                          patientName: patient.patientName),
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Name & Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(patient.statusDisplayName ?? ''),
                          backgroundColor: Colors.blue[50],
                          labelStyle: TextStyle(fontWeight: FontWeight.bold,
                              color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Age: ${patient.age}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Contact: ${patient.contactInfo ?? ""}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Address: ${patient.address}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Problem: ${patient.problem}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Preferred Time: ${patient.preferredTime}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Referred by: ${patient.doctorName}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Assigned therapist: ${patient.therapistName}',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
