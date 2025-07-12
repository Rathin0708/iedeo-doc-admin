import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/admin_patient.dart';
import '../models/therapist_model.dart';
import '../models/visit_log.dart';
import '../services/visit_service.dart';

class TherapistPatientsScreen extends StatefulWidget {
  final TherapistModel therapist;

  const TherapistPatientsScreen({Key? key, required this.therapist}) : super(key: key);

  @override
  State<TherapistPatientsScreen> createState() => _TherapistPatientsScreenState();
}

class _TherapistPatientsScreenState extends State<TherapistPatientsScreen> {
  final VisitService visitService = VisitService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, bool> expandedPatients = {};
  Map<String, TextEditingController> notesControllers = {};

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.therapist.name}\'s Patients'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Therapist info card
            _buildTherapistInfoCard(),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Patients list
            Expanded(
              child: FutureBuilder<List<AdminPatient>>(
                future: visitService.getPatientsByTherapist(widget.therapist.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading patients: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final patients = snapshot.data ?? [];
                  
                  // Filter patients based on search query
                  final filteredPatients = _searchQuery.isEmpty
                    ? patients
                    : patients.where((patient) {
                        final query = _searchQuery.toLowerCase();
                        return patient.patientName.toLowerCase().contains(query) ||
                               patient.problem.toLowerCase().contains(query) ||
                               patient.address.toLowerCase().contains(query);
                      }).toList();
                  
                  if (filteredPatients.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No patients found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: filteredPatients.length,
                    itemBuilder: (context, index) {
                      return _buildPatientCard(filteredPatients[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.therapist.name.isNotEmpty ? widget.therapist.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 24, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.therapist.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (widget.therapist.specialization?.isNotEmpty ?? false)
                    Text(
                      widget.therapist.specialization!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  if (widget.therapist.qualification?.isNotEmpty ?? false)
                    Text(
                      widget.therapist.qualification!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(widget.therapist.email),
                    ],
                  ),
                  if (widget.therapist.phone?.isNotEmpty ?? false)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(widget.therapist.phone!),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(AdminPatient patient) {
    // Ensure we have a controller for this patient
    if (!notesControllers.containsKey(patient.id)) {
      notesControllers[patient.id] = TextEditingController();
    }
    
    // Get the expanded state for this patient
    final isExpanded = expandedPatients[patient.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient header with expand/collapse button
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              patient.patientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              'Problem: ${patient.problem}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<int>(
                  stream: visitService.getVisitCountForPatient(patient.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Chip(
                      label: Text('$count visits'),
                      backgroundColor: Colors.blue.shade100,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      expandedPatients[patient.id] = !isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Patient details section
          if (isExpanded) ...[                        
            // Patient information card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient details
                  const Text(
                    'Patient Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Age', '${patient.age}'),
                  _buildInfoRow('Address', patient.address),
                  _buildInfoRow('Contact', patient.contactInfo),
                  _buildInfoRow('Preferred Time', patient.preferredTime),
                  _buildInfoRow('Status', patient.statusDisplayName),
                  
                  const Divider(height: 24),
                  
                  // Visit logs section
                  const Text(
                    'Visit History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  
                  // Visit logs list
                  StreamBuilder<List<VisitLog>>(
                    stream: visitService.getVisitLogsForPatient(patient.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No visit logs available')),
                        );
                      }
                      
                      final logs = snapshot.data!;
                      
                      return Column(
                        children: logs.map((log) {
                          final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a')
                              .format(log.visitDate.toLocal());
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14),
                                        const SizedBox(width: 8),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    StreamBuilder<String>(
                                      stream: visitService.getTherapistNameStream(log.therapistId),
                                      builder: (context, snapshot) {
                                        final name = snapshot.data ?? log.therapistId;
                                        return Text(
                                          'By: $name',
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Text(log.notes),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Add new visit log section
                  const Text(
                    'Add New Visit Log',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: notesControllers[patient.id],
                          decoration: const InputDecoration(
                            hintText: 'Enter visit notes...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final notes = notesControllers[patient.id]!.text.trim();
                          if (notes.isNotEmpty) {
                            await visitService.addVisitLog(
                              widget.therapist.id,
                              patient.id,
                              DateTime.now(),
                              notes,
                            );
                            notesControllers[patient.id]!.clear();
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
