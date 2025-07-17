import 'package:flutter/material.dart';
import 'admin_dashboard.dart'; // import the function

class TherapistReferralsScreen extends StatelessWidget {
  final String therapistId; // This is the UID for the selected therapist
  final Map<String, dynamic> therapistData;

  const TherapistReferralsScreen(
      {Key? key, required this.therapistId, required this.therapistData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final therapistName = therapistData['name'] ?? 'Therapist';
    return Scaffold(
      appBar: AppBar(
        title: Text('Assigned Patients for $therapistName'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Query only patients where therapistId matches the tapped therapistUid (admin assignment)
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: getPatientsForTherapist(therapistId),
          // use the helper function
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final assignedPatients = snapshot.data ?? [];
            if (assignedPatients.isEmpty) {
              return Center(
                  child: Text('No patients assigned to $therapistName.'));
            }
            return ListView.separated(
              itemCount: assignedPatients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final patient = assignedPatients[index];
                final patientName = patient['name']?.toString() ?? 'N/A';
                final patientEmail = patient['email']?.toString() ?? 'N/A';
                final patientPhone = patient['phone']?.toString() ?? 'N/A';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        patientName.isNotEmpty
                            ? patientName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(patientName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (patientEmail != 'N/A') Text('Email: $patientEmail'),
                        if (patientPhone != 'N/A') Text('Phone: $patientPhone'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
