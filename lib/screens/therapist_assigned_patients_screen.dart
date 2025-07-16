import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';
import 'patient_visit_logs_screen.dart';

class TherapistAssignedPatientsScreen extends StatefulWidget {
  final String therapistId;
  final String therapistName;
  final String? currentStatus;
  final String? lastUpdated;
  final String? lastVisit;
  final String? preferredDateTime;
// ... (add to constructor and fromMap/fromJson methods as well)


  const TherapistAssignedPatientsScreen({
    super.key,
    required this.therapistId,
    required this.therapistName, this.currentStatus, this.lastUpdated, this.lastVisit, this.preferredDateTime
  });

  @override
  State<TherapistAssignedPatientsScreen> createState() =>
      _TherapistAssignedPatientsScreenState();
}

class _TherapistAssignedPatientsScreenState
    extends State<TherapistAssignedPatientsScreen> {
  String _searchQuery = '';
  String _status = 'All';
  String _problem = 'All';

  @override
  Widget build(BuildContext context) {
    // Access allPatients via Provider (already up-to-date in app memory)
    final allPatients = Provider
        .of<AdminFirebaseService>(context, listen: false)
        .allPatients;
    // Filter for assigned patients to this therapist
    final assignedPatients = allPatients.where((p) =>
    p.therapistId == widget.therapistId).toList();

    // Compute status and problem lists for dropdowns
    final uniqueStatuses = [
      'All',
      ...{for (var p in assignedPatients) (p.statusDisplayName ?? '').trim()}
          .where((s) => s.isNotEmpty)
    ];
    final uniqueProblems = [
      'All',
      ...{for (var p in assignedPatients) p.problem.trim()}.where((p) =>
      p
          .isNotEmpty)
    ];

    // Combined filtering logic: search + status + problem
    final filteredPatients = assignedPatients.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty
          || p.patientName.toLowerCase().contains(q)
          || (p.contactInfo ?? '').toLowerCase().contains(q)
          || p.problem.toLowerCase().contains(q)
          || p.address.toLowerCase().contains(q);
      final matchesStatus = (_status == 'All' ||
          (p.statusDisplayName ?? '') == _status);
      final matchesProblem = (_problem == 'All' || p.problem == _problem);
      return matchesSearch && matchesStatus && matchesProblem;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor:  Color(0xFF4CAF7E),
          title: Text('Assigned Patients for ${widget.therapistName}')),
      body: Column(
        children: [
          // --- Search Bar Filter ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search patients (name, contact, problem, address)...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                    : null,
              ),
              onChanged: (text) => setState(() => _searchQuery = text.trim()),
            ),
          ),
          // --- Advanced Filters: Status + Problem ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                // Status Filter Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    items: uniqueStatuses.map((s) =>
                        DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _status = val!),
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Problem Filter Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _problem,
                    items: uniqueProblems.map((p) =>
                        DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) => setState(() => _problem = val!),
                    decoration: InputDecoration(
                      labelText: 'Problem',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.clear_all),
                  tooltip: 'Clear filters',
                  onPressed: () =>
                      setState(() {
                        _status = 'All';
                        _problem = 'All';
                        _searchQuery = '';
                      }),
                )
              ],
            ),
          ),
          // --- Assigned Patients List ---
          Expanded(
            child: filteredPatients.isEmpty
                ? Center(child: Text(
                'No patients assigned to ${widget.therapistName}${_searchQuery
                    .isNotEmpty || _status != 'All' || _problem != 'All'
                    ? ' (or no matching filters)'
                    : ''}'))
                : ListView.builder(
              itemCount: filteredPatients.length,
              itemBuilder: (context, index) {
                final patient = filteredPatients[index];
                // Same as before: patient card + onTap opens visit logs
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PatientVisitLogsScreen(
                                patientId: patient.id,
                                patientName: patient.patientName, name: '',),
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
                              Text('Patient Name: ${patient.patientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Patient ID: ${patient.id}'),
                              Text('Age: ${patient.age}'),
                              Text('Address: ${patient.address}'),
                              Text('Contact Info: ${patient.contactInfo ?? ""}'),
                              Text('Assigned At: ${patient.assignedAt ?? ""}'),
                              Text('Created At: ${patient.createdAt ?? ""}'),
                              Text('Doctor ID: ${patient.doctorId ?? ""}'),
                              Text('Doctor Name: ${patient.doctorName ?? ""}'),
                              Text('Follow Up Required: ${patient.followUpRequired == true ? "Yes" : "No"}'),
                              Text('Preferred Time: ${patient.preferredTime ?? ""}'),
                              Text('Problem: ${patient.problem}'),
                              Text('Assigned Therapist: ${patient.therapistName}'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: SizedBox()),
                                  Chip(
                                    label: Text(patient.statusDisplayName ?? ''),
                                    backgroundColor: Colors.blue[50],
                                    labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                                  ),
                                ],
                              ),
                            ],
                          )

                      ),
                    )

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
