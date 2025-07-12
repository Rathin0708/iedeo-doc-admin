import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/admin_patient.dart';
import '../models/visit_model.dart';
import '../services/admin_auth_service.dart';
import '../services/visit_service.dart';

class AddVisitLogScreen extends StatefulWidget {
  final AdminPatient patient;
  
  const AddVisitLogScreen({Key? key, required this.patient}) : super(key: key);

  @override
  State<AddVisitLogScreen> createState() => _AddVisitLogScreenState();
}

class _AddVisitLogScreenState extends State<AddVisitLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitService = VisitService();
  
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  final _notesController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _progressNotesController = TextEditingController();
  final _visitNotesController = TextEditingController();
  final _vasPainScoreController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _status = 'completed';
  bool _followUpRequired = false;
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _notesController.dispose();
    _treatmentPlanController.dispose();
    _progressNotesController.dispose();
    _visitNotesController.dispose();
    _vasPainScoreController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _visitDate) {
      setState(() {
        _visitDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
    );
    if (picked != null && picked != _visitTime) {
      setState(() {
        _visitTime = picked;
      });
    }
  }
  
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      
      try {
        final therapistId = Provider.of<AdminAuthService>(context, listen: false).currentUserUid ?? '';
        final therapistName = Provider.of<AdminAuthService>(context, listen: false).currentUserName ?? '';
        
        // Format time as string
        final formattedTime = '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}';
        
        // Create visit model
        final visit = VisitModel(
          id: '', // Will be assigned by Firestore
          patientId: widget.patient.id,
          therapistId: therapistId,
          therapistName: therapistName,
          visitDate: _visitDate,
          visitTime: formattedTime,
          notes: _notesController.text.trim(),
          status: _status,
          followUpRequired: _followUpRequired,
          vasPainScore: _vasPainScoreController.text.trim(),
          amount: double.tryParse(_amountController.text.trim()) ?? 0,
          treatmentPlan: _treatmentPlanController.text.trim(),
          progressNotes: _progressNotesController.text.trim(),
          visitNotes: _visitNotesController.text.trim(),
          createdAt: DateTime.now(),
        );
        
        await _visitService.addTreatmentLog(visit);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Treatment log added successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding treatment log: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Treatment Log for ${widget.patient.patientName}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient info card
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient: ${widget.patient.patientName}', 
                        style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Problem: ${widget.patient.problem}'),
                      Text('Age: ${widget.patient.age}'),
                    ],
                  ),
                ),
              ),
              
              // Visit date and time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Visit Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('MMM d, y').format(_visitDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Visit Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_visitTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Treatment notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Treatment Notes *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter treatment notes',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter treatment notes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Treatment plan
              TextFormField(
                controller: _treatmentPlanController,
                decoration: const InputDecoration(
                  labelText: 'Treatment Plan',
                  border: OutlineInputBorder(),
                  hintText: 'Enter treatment plan',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Progress notes
              TextFormField(
                controller: _progressNotesController,
                decoration: const InputDecoration(
                  labelText: 'Progress Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Enter progress notes',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Visit notes
              TextFormField(
                controller: _visitNotesController,
                decoration: const InputDecoration(
                  labelText: 'Visit Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Enter additional visit notes',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // VAS pain score and amount
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vasPainScoreController,
                      decoration: const InputDecoration(
                        labelText: 'VAS Pain Score (0-10)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 5',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 500',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Status dropdown
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Treatment Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Follow-up checkbox
              CheckboxListTile(
                title: const Text('Follow-up Required'),
                value: _followUpRequired,
                onChanged: (value) {
                  setState(() {
                    _followUpRequired = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('SAVE TREATMENT LOG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
