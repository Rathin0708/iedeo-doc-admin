import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientVisitLogsScreen extends StatefulWidget {
  final String patientId;
  final String name;

  const PatientVisitLogsScreen({
    Key? key,
    required this.patientId,
    required this.name, String? patientName,
  }) : super(key: key);

  @override
  State<PatientVisitLogsScreen> createState() => _PatientVisitLogsScreenState();
}

class _PatientVisitLogsScreenState extends State<PatientVisitLogsScreen> {
  DateTimeRange? _dateRange;
  String _visitType = 'All';
  String _status = 'All';
  bool _showFilters = false;

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  List<QueryDocumentSnapshot> _applyFilters(
      List<QueryDocumentSnapshot> visits) {
    return visits.where((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      final visitDate = data['visitDate'] != null
          ? (data['visitDate'] as Timestamp).toDate()
          : null;
      final visitType = data['visitType'] ?? '';
      final status = data['status'] ?? '';

      bool matches = true;
      if (_dateRange != null && visitDate != null) {
        matches &= visitDate.isAfter(
            _dateRange!.start.subtract(const Duration(days: 1))) &&
            visitDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }
      if (_visitType != 'All' && _visitType.isNotEmpty) {
        matches &= visitType == _visitType;
      }
      if (_status != 'All' && _status.isNotEmpty) {
        matches &= status == _status;
      }
      return matches;
    }).toList();
  }

  // For visit type dropdown
  static const visitTypeOptions = [
    'All',
    'Initial Assessment',
    'Follow Up',
    'Discharge',
  ];
  static const statusOptions = [
    'All',
    'Ongoing',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visit Logs for ${widget.name}'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 10,
                children: [
                  // Date filter
                  ElevatedButton.icon(
                    icon: Icon(Icons.date_range),
                    label: Text(_dateRange == null
                        ? 'Date'
                        : '${_formatDate(_dateRange!.start)} to ${_formatDate(
                        _dateRange!.end)}'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _dateRange,
                      );
                      if (picked != null) {
                        setState(() => _dateRange = picked);
                      }
                    },
                  ),
                  // Quick clear for date
                  if (_dateRange != null)
                    IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () => setState(() => _dateRange = null)),
                  // Visit type filter
                  DropdownButton<String>(
                    value: _visitType,
                    items: visitTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setState(() => _visitType = val!),
                    hint: Text('Visit Type'),
                  ),
                  // Status
                  DropdownButton<String>(
                    value: _status,
                    items: statusOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _status = val!),
                    hint: Text('Status'),
                  ),
                  // Quick clear all
                  TextButton(
                    child: Text('Clear All'),
                    onPressed: () =>
                        setState(() {
                          _dateRange = null;
                          _visitType = 'All';
                          _status = 'All';
                        }),
                  ),
                ],
              ),
            ),
          // Visit log list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visits')
                  .where('patientId', isEqualTo: widget.patientId)
                  .orderBy('visitDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Firestore error: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final visits = snapshot.data?.docs ?? [];
                final filteredVisits = _applyFilters(visits);
                if (filteredVisits.isEmpty) {
                  return Center(
                      child: Text('No visits found for selected filters.'));
                }
                return ListView.builder(
                  itemCount: filteredVisits.length,
                  itemBuilder: (context, idx) {
                    final visit = filteredVisits[idx].data() as Map<
                        String,
                        dynamic>;
                    final visitDate = visit['visitDate'] != null
                        ? (visit['visitDate'] as Timestamp).toDate()
                        : null;
                    final visitType = visit['visitType'] ?? 'N/A';
                    final therapistName = visit['therapistName'] ?? 'N/A';
                    // Guaranteed fallback: if patientName is missing in visit log doc, use the name passed in from parent screen
                    final patientName = visit['patientName'] ??
                        widget.name;
                    final quickNotes = (visit['quickNotes'] as List?)?.join(
                        ', ') ?? 'None';
                    final visitNotes = visit['visitNotes'] ?? '';
                    final vasPainScore = visit['vasPainScore']?.toString() ??
                        '';
                    final treatmentPlan = visit['treatmentPlan'] ?? '';
                    final progressNotes = visit['progressNotes'] ?? '';
                    final amount = visit['amount']?.toString() ?? '';
                    final status = visit['status'] ?? '';
                    final followUp = (visit['followUpRequired'] ?? false)
                        ? 'Yes'
                        : 'No';

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main heading: Date and type
                            Text(
                              'Visit Date: ${visitDate != null ? "${visitDate
                                  .toLocal()}".split('.')[0] : 'N/A'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 3),
                            Text('Type: $visitType',
                                style: const TextStyle(fontSize: 14)),
                            const Divider(height: 18),
                            // Therapist and Patient
                            Text('Therapist: $therapistName',
                                style: const TextStyle(fontSize: 13)),
                            Text('Patient: $patientName',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                            // Clinical fields
                            Text('Quick Notes: $quickNotes',
                                style: const TextStyle(fontSize: 13)),
                            if (visitNotes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Visit Notes: $visitNotes',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            if (vasPainScore.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('VAS Pain Score: $vasPainScore',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            if (treatmentPlan.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Treatment Plan: $treatmentPlan',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            if (progressNotes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Progress Notes: $progressNotes',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            // Admin fields
                            if (amount.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Amount: ₹$amount',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            if (status.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Status: $status',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            const SizedBox(height: 4),
                            Text('Follow-up Required: $followUp',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
