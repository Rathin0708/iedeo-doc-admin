import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientVisitLogsScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const PatientVisitLogsScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Visit Logs for $patientName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visits')
            .where('patientId', isEqualTo: patientId)
            .orderBy('visitDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore error: ${snapshot.error}'); // <-- always prints to terminal/log
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final visits = snapshot.data?.docs ?? [];
          if (visits.isEmpty) {
            return Center(child: Text('No visits yet for $patientName'));
          }
          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, idx) {
              final visit = visits[idx].data() as Map<String, dynamic>;
              final visitDate = visit['visitDate'] != null
                  ? (visit['visitDate'] as Timestamp).toDate()
                  : null;
              final visitType = visit['visitType'] ?? 'N/A';
              final quickNotes = (visit['quickNotes'] as List?)?.join(', ') ?? 'None';
              final visitNotes = visit['visitNotes'] ?? '';
              final vasPainScore = visit['vasPainScore']?.toString() ?? '-';
              final treatmentPlan = visit['treatmentPlan'] ?? '';
              final progressNotes = visit['progressNotes'] ?? '';
              final amount = visit['amount']?.toString() ?? '';
              final status = visit['status'] ?? '';
              final followUp = (visit['followUpRequired'] ?? false) ? 'Yes' : 'No';

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Visit Date: ${visitDate != null ? "${visitDate.toLocal()}".split('.')[0] : 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text("Type: $visitType"),
                      Text("Quick Notes: $quickNotes"),
                      if (visitNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Visit Notes: $visitNotes"),
                      ],
                      if (vasPainScore != '-') ...[
                        const SizedBox(height: 6),
                        Text("VAS Pain Score: $vasPainScore"),
                      ],
                      if (treatmentPlan.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Treatment Plan: $treatmentPlan"),
                      ],
                      if (progressNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Progress Notes: $progressNotes"),
                      ],
                      if (amount.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Amount: ₹$amount"),
                      ],
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Status: $status"),
                      ],
                      const SizedBox(height: 6),
                      Text("Follow-up Required: $followUp"),
                    ],
                  ),
                ),
              );
            },
          );

        },
      ),
    );
  }
}
