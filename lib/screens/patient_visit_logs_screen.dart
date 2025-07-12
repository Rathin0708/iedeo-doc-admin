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
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final visits = snapshot.data?.docs ?? [];
          if (visits.isEmpty) {
            return Center(child: Text('No visits yet for $patientName'));
          }
          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, idx) {
              final visit = visits[idx].data() as Map<String, dynamic>;
              final date = visit['visitDate'] != null
                  ? (visit['visitDate'] as Timestamp)
                  .toDate()
                  .toString()
                  .substring(0, 16)
                  : 'N/A';
              final notes = visit['notes'] ?? 'No notes';
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Visit on $date'),
                  subtitle: Text(notes),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
