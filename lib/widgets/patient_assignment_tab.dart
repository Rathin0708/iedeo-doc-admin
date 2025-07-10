import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // For image compression
import 'package:flutter/foundation.dart';
import '../services/admin_firebase_service.dart';
import '../models/admin_patient.dart';
import '../models/admin_user.dart';

class PatientAssignmentTab extends StatefulWidget {
  const PatientAssignmentTab({super.key});

  @override
  State<PatientAssignmentTab> createState() => _PatientAssignmentTabState();
}

class _PrescriptionImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _PrescriptionImageViewer({
    Key? key,
    required this.imageUrls,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<_PrescriptionImageViewer> createState() =>
      _PrescriptionImageViewerState();
}

class _PrescriptionImageViewerState extends State<_PrescriptionImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          itemBuilder: (context, index) {
            return InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress
                            .expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 70,
                                  color: Colors.grey[700]),
                              const SizedBox(height: 8),
                              Text(
                                'Could not load image',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 36,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: TextStyle(color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.save_alt, color: Colors.white, size: 26),
                  onPressed: () {
                    // Optionally implement: Save image to device
                  },
                  tooltip: 'Save Image',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientAssignmentTabState extends State<PatientAssignmentTab>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Helper to show 'x time ago' label
  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  /// Displays a section with thumbnails for prescription images (or a "No images" message if none)
  Widget _buildPrescriptionImagesSection(BuildContext context,
      AdminPatient patient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Prescription Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              List<String> prescriptionImageUrls = patient.prescriptionImages;
              if (prescriptionImageUrls.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.image_not_supported, size: 48,
                          color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No prescription images available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Images are attached when adding patients',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prescriptionImageUrls.length} Image(s) Available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: prescriptionImageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () =>
                              _showFullScreenPrescriptionImage(
                                  context, prescriptionImageUrls, index),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.network(
                                    prescriptionImageUrls[index],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child,
                                        loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                .expectedTotalBytes != null
                                                ? loadingProgress
                                                .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error,
                                        stackTrace) =>
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue[100]!,
                                                Colors.purple[100]!
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment
                                                .center,
                                            children: [
                                              Icon(Icons.broken_image, size: 32,
                                                  color: Colors.grey[600]),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Failed to load',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Shows the full-screen image gallery viewer starting at the given index
  void _showFullScreenPrescriptionImage(BuildContext context,
      List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.all(0),
          child: _PrescriptionImageViewer(
              imageUrls: imageUrls, initialIndex: initialIndex),
        );
      },
    );
  }

  // Filter states
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _doctorFilter = 'All';
  String _therapistFilter = 'All';
  DateTimeRange? _dateRange;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPatientDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Patient'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminFirebaseService>(
        builder: (context, firebaseService, child) {
          if (firebaseService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final unassignedPatients = firebaseService.unassignedPatients;
          final allPatients = firebaseService.allPatients;

          return Column(
            children: [
              // Header with stats and add button
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${unassignedPatients
                                .length} pending • ${allPatients
                                .length} total patients',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => firebaseService.refreshData(),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Search and Filter Section
              _buildSearchAndFilters(context),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[500]!, Colors.blue[700]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions, size: 16),
                          const SizedBox(width: 8),
                          Text('Unassigned (${unassignedPatients.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 16),
                          const SizedBox(width: 8),
                          Text('All (${allPatients.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: NeverScrollableScrollPhysics(), // prevent swipe
                  children: [
                    _buildPatientsList(
                        context, firebaseService, unassignedPatients, true),
                    _buildPatientsList(
                        context, firebaseService, allPatients, false),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search patients by name, contact, or problem...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue[600]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Filter Toggle Button
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: _showFilters ? Colors.blue[600] : Colors.grey[600],
                ),
                tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
              ),
              // Advanced Filter Button
              ElevatedButton.icon(
                onPressed: () => _showAdvancedFiltersDialog(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Advanced'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          // Quick Filter Chips (when expanded)
          if (_showFilters) ...[
            const SizedBox(height: 16),
            _buildQuickFilters(),
          ],

          // Active Filters Display
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            _buildActiveFiltersChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Quick Filters',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('All Status', _statusFilter == 'All', () {
              setState(() {
                _statusFilter = 'All';
              });
            }),
            _buildFilterChip('Unassigned', _statusFilter == 'Unassigned', () {
              setState(() {
                _statusFilter = 'Unassigned';
              });
            }),
            _buildFilterChip('Assigned', _statusFilter == 'Assigned', () {
              setState(() {
                _statusFilter = 'Assigned';
              });
            }),
            _buildFilterChip('Visited', _statusFilter == 'Visited', () {
              setState(() {
                _statusFilter = 'Visited';
              });
            }),
            _buildFilterChip('Ongoing', _statusFilter == 'Ongoing', () {
              setState(() {
                _statusFilter = 'Ongoing';
              });
            }),
            _buildFilterChip('Completed', _statusFilter == 'Completed', () {
              setState(() {
                _statusFilter = 'Completed';
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => onTap(),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue[600],
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildActiveFiltersChips() {
    List<Widget> chips = [];

    if (_searchQuery.isNotEmpty) {
      chips.add(_buildActiveFilterChip('Search: "\$_searchQuery"', () {
        setState(() {
          _searchQuery = '';
        });
      }));
    }

    if (_statusFilter != 'All') {
      chips.add(_buildActiveFilterChip('Status: \$_statusFilter', () {
        setState(() {
          _statusFilter = 'All';
        });
      }));
    }

    if (_doctorFilter != 'All') {
      chips.add(_buildActiveFilterChip('Doctor: \$_doctorFilter', () {
        setState(() {
          _doctorFilter = 'All';
        });
      }));
    }

    if (_therapistFilter != 'All') {
      chips.add(_buildActiveFilterChip('Therapist: \$_therapistFilter', () {
        setState(() {
          _therapistFilter = 'All';
        });
      }));
    }

    if (_dateRange != null) {
      chips.add(_buildActiveFilterChip(
          'Date: \${_formatDate(_dateRange!.start)} - \${_formatDate(_dateRange!.end)}',
              () {
            setState(() {
              _dateRange = null;
            });
          }
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'Active Filters:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      backgroundColor: Colors.blue[50],
      deleteIconColor: Colors.blue[600],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _statusFilter != 'All' ||
        _doctorFilter != 'All' ||
        _therapistFilter != 'All' ||
        _dateRange != null;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _doctorFilter = 'All';
      _therapistFilter = 'All';
      _dateRange = null;
    });
  }

  void _showAdvancedFiltersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) =>
          StatefulBuilder(
            builder: (context, setDialogState) =>
                AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text('Advanced Filters'),
                    ],
                  ),
                  content: Container(
                    width: MediaQuery
                        .of(context)
                        .size
                        .width * 0.8,
                    height: MediaQuery
                        .of(context)
                        .size
                        .height * 0.6,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Range Filter
                          const Text('Date Range',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final DateTimeRange? picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                    const Duration(days: 365)),
                                lastDate: DateTime.now().add(
                                    const Duration(days: 365)),
                                initialDateRange: _dateRange,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  _dateRange = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dateRange != null
                                        ? '\${_formatDate(_dateRange!.start)} - \${_formatDate(_dateRange!.end)}'
                                        : 'Select date range',
                                  ),
                                  const Spacer(),
                                  if (_dateRange != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setDialogState(() {
                                          _dateRange = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Doctor Filter
                          const Text('Filter by Doctor',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Consumer<AdminFirebaseService>(
                            builder: (context, firebaseService, child) {
                              final doctors = _getUniqueDoctors(firebaseService
                                  .allPatients);
                              return DropdownButtonFormField<String>(
                                value: _doctorFilter,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.local_hospital),
                                ),
                                items: ['All', ...doctors].map((doctor) {
                                  return DropdownMenuItem(
                                    value: doctor,
                                    child: Text(doctor),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    _doctorFilter = value!;
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Therapist Filter
                          const Text('Filter by Therapist',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Consumer<AdminFirebaseService>(
                            builder: (context, firebaseService, child) {
                              final therapists = _getUniqueTherapists(
                                  firebaseService.allPatients);
                              return DropdownButtonFormField<String>(
                                value: _therapistFilter,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.healing),
                                ),
                                items: ['All', ...therapists].map((therapist) {
                                  return DropdownMenuItem(
                                    value: therapist,
                                    child: Text(therapist),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    _therapistFilter = value!;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Reset filters
                        setDialogState(() {
                          _statusFilter = 'All';
                          _doctorFilter = 'All';
                          _therapistFilter = 'All';
                          _dateRange = null;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                setState(() {
                  // Apply filters - they're already set in the dialog state
                });
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getUniqueDoctors(List<AdminPatient> patients) {
    return patients
        .map((p) => p.doctorName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueTherapists(List<AdminPatient> patients) {
    return patients
        .where((p) => p.therapistName != null && p.therapistName!.isNotEmpty)
        .map((p) => p.therapistName!)
        .toSet()
        .toList()
      ..sort();
  }

  Widget _buildPatientsList(BuildContext context,
      AdminFirebaseService firebaseService,
      List<AdminPatient> patients, bool showAssignButton) {
    // Apply filters
    List<AdminPatient> filteredPatients = _applyFilters(patients);

    // Sort: For "All" patients tab (i.e., showAssignButton == false), sort patients by assignedAt (if available), else createdAt, descending (most recent first)
    if (!showAssignButton) {
      filteredPatients.sort((a, b) {
        final aTime = a.assignedAt ?? a.createdAt;
        final bTime = b.assignedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    }

    if (filteredPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasActiveFilters() ? Icons.search_off :
              (showAssignButton ? Icons.assignment_turned_in : Icons
                  .people_outline),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters() ? 'No Matching Patients' :
              (showAssignButton
                  ? 'All Patients Assigned'
                  : 'No Patients Found'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters()
                  ? 'Try adjusting your filters or search terms'
                  : showAssignButton
                  ? 'No patients waiting for assignment'
                  : 'Add your first patient to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_hasActiveFilters()) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results counter
        if (_hasActiveFilters())
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Showing ${filteredPatients.length} of ${patients
                  .length} patients',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Patient list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPatients.length,
            itemBuilder: (context, index) {
              final patient = filteredPatients[index];
              return _buildPatientCard(
                  context, patient, firebaseService, showAssignButton);
            },
          ),
        ),
      ],
    );
  }

  List<AdminPatient> _applyFilters(List<AdminPatient> patients) {
    List<AdminPatient> filtered = patients;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((patient) {
        return patient.patientName.toLowerCase().contains(_searchQuery) ||
            patient.contactInfo.toLowerCase().contains(_searchQuery) ||
            patient.problem.toLowerCase().contains(_searchQuery) ||
            patient.address.toLowerCase().contains(_searchQuery) ||
            patient.doctorName.toLowerCase().contains(_searchQuery) ||
            (patient.therapistName?.toLowerCase().contains(_searchQuery) ??
                false);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((patient) {
        switch (_statusFilter) {
          case 'Unassigned':
            return patient.isUnassigned;
          case 'Assigned':
            return patient.isAssigned &&
                patient.status.toLowerCase() == 'assigned';
          case 'Visited':
            return patient.status.toLowerCase() == 'visited';
          case 'Ongoing':
            return patient.status.toLowerCase() == 'ongoing';
          case 'Completed':
            return patient.status.toLowerCase() == 'completed';
          default:
            return true;
        }
      }).toList();
    }

    // Apply doctor filter
    if (_doctorFilter != 'All') {
      filtered = filtered.where((patient) {
        return patient.doctorName == _doctorFilter;
      }).toList();
    }

    // Apply therapist filter
    if (_therapistFilter != 'All') {
      filtered = filtered.where((patient) {
        return patient.therapistName == _therapistFilter;
      }).toList();
    }

    // Apply date range filter
    if (_dateRange != null) {
      filtered = filtered.where((patient) {
        return patient.createdAt.isAfter(
            _dateRange!.start.subtract(const Duration(days: 1))) &&
            patient.createdAt.isBefore(
                _dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Widget _buildPatientCard(BuildContext context, AdminPatient patient,
      AdminFirebaseService firebaseService, bool showAssignButton) {
    // Display both 'Added' and 'Assigned' dates as separate rows

    final dateAdded = patient.createdAt;
    final timeAgoAdded = _timeAgo(dateAdded);
    final dateAssigned = patient.assignedAt;
    final timeAgoAssigned = dateAssigned != null
        ? _timeAgo(dateAssigned)
        : null;

    // Calculate time difference in hours for "Added" and "Assigned"
    final now = DateTime.now();
    final addedDiffHours = now
        .difference(dateAdded)
        .inHours;
    final assignedDiffHours = dateAssigned != null ? now
        .difference(dateAssigned)
        .inHours : 0;

    // Helper: Format as h:mm am/pm
    String getTimeHHMM(DateTime dt) {
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'pm' : 'am';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $ampm';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with patient name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    patient.patientName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildStatusChip(patient.status, patient.isUnassigned),
              ],
            ),
            const SizedBox(height: 16),

            // --- Show date + ago OR date + time, never both time and ago ---
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text('Added: ', style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.blue)),
                if (addedDiffHours < 2) ...[
                  Text(_formatDateDMY(dateAdded),
                      style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                  const SizedBox(width: 6),
                  Text('($timeAgoAdded ago)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ] else
                  ...[
                    Text('${_formatDateDMY(dateAdded)} ${getTimeHHMM(
                        dateAdded)}', style: TextStyle(
                        fontSize: 12, color: Colors.blue[600])),
                ],
              ],
            ),
            if (dateAssigned != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.assignment_turned_in, size: 16,
                      color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Assigned: ', style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.green)),
                  if (assignedDiffHours < 2) ...[
                    Text(_formatDateDMY(dateAssigned!), style: TextStyle(
                        fontSize: 12, color: Colors.green[800])),
                    const SizedBox(width: 6),
                    Text('(${timeAgoAssigned} ago)', style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                  ] else
                    ...[
                      Text('${_formatDateDMY(dateAssigned!)} ${getTimeHHMM(
                          dateAssigned!)}', style: TextStyle(
                          fontSize: 12, color: Colors.green[800])),
                  ],
                ],
              ),
            ],
            // -------------------------------------------------------------------

            const SizedBox(height: 12),

            // Patient details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                      Icons.cake, 'Age', '${patient.age} years', Colors.blue),
                  const Divider(height: 16),
                  _buildInfoRow(Icons.phone, 'Contact', patient.contactInfo,
                      Colors.green),
                  const Divider(height: 16),
                  _buildInfoRow(Icons.location_on, 'Address', patient.address,
                      Colors.orange),
                  const Divider(height: 16),
                  _buildInfoRow(
                      Icons.medical_services, 'Problem', patient.problem,
                      Colors.red),
                  const Divider(height: 16),
                  _buildInfoRow(
                      Icons.schedule, 'Preferred Time', patient.preferredTime,
                      Colors.purple),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Doctor info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text('Referred by: ', style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.blue[800])),
                  Text(patient.doctorName, style: TextStyle(
                      color: Colors.blue[700], fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            // Therapist info (if assigned)
            if (patient.isAssigned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.healing, size: 20, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Text('Assigned to: ', style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.green[800])),
                    Text(patient.therapistName ?? 'Unknown', style: TextStyle(
                        color: Colors.green[700], fontWeight: FontWeight.w500)),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          _reassignPatient(context, patient, firebaseService),
                      icon: Icon(Icons.swap_horiz, color: Colors.green[600]),
                      tooltip: 'Reassign to different therapist',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (showAssignButton || patient.isUnassigned)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _assignPatient(context, patient, firebaseService),
                      icon: const Icon(Icons.assignment_ind, size: 20),
                      label: Text(patient.isUnassigned
                          ? 'Assign Therapist'
                          : 'Reassign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (patient.isAssigned) ...[
                  if (showAssignButton || patient.isUnassigned) const SizedBox(
                      width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewPatientDetails(context, patient),
                      icon: const Icon(Icons.visibility, size: 20),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                        side: BorderSide(color: Colors.blue[600]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isUnassigned) {
    Color color;
    String displayText;

    if (isUnassigned) {
      color = Colors.red;
      displayText = 'AWAITING ASSIGNMENT';
    } else {
      switch (status.toLowerCase()) {
        case 'assigned':
          color = Colors.blue;
          displayText = 'ASSIGNED';
          break;
        case 'visited':
          color = Colors.green;
          displayText = 'VISITED';
          break;
        case 'ongoing':
          color = Colors.orange;
          displayText = 'ONGOING';
          break;
        case 'completed':
          color = Colors.teal;
          displayText = 'COMPLETED';
          break;
        default:
          color = Colors.grey;
          displayText = status.toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format as DD-MM-YYYY
  String _formatDateDMY(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month
        .toString()
        .padLeft(2, '0')}-${date.year}';
  }

  void _showAddPatientDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final patientNameController = TextEditingController();
    final ageController = TextEditingController();
    final contactInfoController = TextEditingController();
    final addressController = TextEditingController();
    final problemController = TextEditingController();
    final doctorNameController = TextEditingController();
    // Preferred date/time for the appointment/referral
    DateTime? preferredDateTime;

    List<Uint8List> prescriptionImages = []; // Store actual image bytes

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          StatefulBuilder(
            builder: (context, setState) =>
                AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text('Add New Patient'),
                    ],
                  ),
                  content: Container(
                    width: MediaQuery
                        .of(context)
                        .size
                        .width * 0.8,
                    height: MediaQuery
                        .of(context)
                        .size
                        .height * 0.7,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: patientNameController,
                              decoration: InputDecoration(
                                labelText: 'Patient Name *',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter patient name'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: ageController,
                              decoration: InputDecoration(
                                labelText: 'Age *',
                                prefixIcon: const Icon(Icons.cake),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter age'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: contactInfoController,
                              decoration: InputDecoration(
                                labelText: 'Contact Number *',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter contact number'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: addressController,
                              decoration: InputDecoration(
                                labelText: 'Address *',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              maxLines: 2,
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter address'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: problemController,
                              decoration: InputDecoration(
                                labelText: 'Medical Problem/Complaint *',
                                prefixIcon: const Icon(Icons.medical_services),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              maxLines: 3,
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter medical problem'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: doctorNameController,
                              decoration: InputDecoration(
                                labelText: 'Referring Doctor *',
                                prefixIcon: const Icon(Icons.local_hospital),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (value) =>
                              value?.isEmpty == true
                                  ? 'Please enter doctor name'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: preferredDateTime ??
                                              DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(
                                              const Duration(days: 365)));
                                      if (pickedDate != null) {
                                        // If no time chosen yet, default to 10am
                                        preferredDateTime = DateTime(
                                          pickedDate.year,
                                          pickedDate.month,
                                          pickedDate.day,
                                          preferredDateTime?.hour ?? 10,
                                          preferredDateTime?.minute ?? 0,
                                        );
                                        setState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                          labelText: 'Preferred Date',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius
                                                  .circular(8)),
                                          prefixIcon: const Icon(
                                              Icons.date_range)),
                                      child: Text(
                                          preferredDateTime != null
                                              ? '${preferredDateTime!
                                              .day}/${preferredDateTime!
                                              .month}/${preferredDateTime!
                                              .year}'
                                              : 'Select Date'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: preferredDateTime != null
                                              ? TimeOfDay(
                                              hour: preferredDateTime!.hour,
                                              minute: preferredDateTime!.minute)
                                              : const TimeOfDay(
                                              hour: 10, minute: 0));
                                      if (pickedTime != null) {
                                        final base = preferredDateTime ??
                                            DateTime.now();
                                        preferredDateTime = DateTime(
                                          base.year,
                                          base.month,
                                          base.day,
                                          pickedTime.hour,
                                          pickedTime.minute,
                                        );
                                        setState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                          labelText: 'Preferred Time',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius
                                                  .circular(8)),
                                          prefixIcon: const Icon(
                                              Icons.access_time)),
                                      child: Text(
                                          preferredDateTime != null
                                              ? '${preferredDateTime!.hour
                                              .toString().padLeft(
                                              2, '0')}:${preferredDateTime!
                                              .minute.toString().padLeft(
                                              2, '0')}'
                                              : 'Select Time'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                    // Prescription Images Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.camera_alt, color: Colors.blue[600]),
                              const SizedBox(width: 8),
                              const Text('Prescription Images',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera);
                                    if (image != null) {
                                      final originalBytes = await image
                                          .readAsBytes();
                                      // Compress
                                      final compressed = await FlutterImageCompress
                                          .compressWithList(
                                        originalBytes,
                                        minWidth: 1024,
                                        minHeight: 1024,
                                        quality: 60, // compress for web/mobile
                                      );
                                      setState(() {
                                        prescriptionImages.add(compressed);
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera),
                                  label: const Text('Take Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final List<XFile> images = await picker
                                        .pickMultiImage();
                                    if (images.isNotEmpty) {
                                      final List<Uint8List> compressedImages = [
                                      ];
                                      for (final image in images) {
                                        final originalBytes = await image
                                            .readAsBytes();
                                        final compressed = await FlutterImageCompress
                                            .compressWithList(
                                          originalBytes,
                                          minWidth: 1024,
                                          minHeight: 1024,
                                          quality: 60,
                                        );
                                        compressedImages.add(compressed);
                                      }
                                      setState(() {
                                        prescriptionImages.addAll(
                                            compressedImages);
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.photo),
                                  label: const Text('Select Images'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (prescriptionImages.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Selected Images: ${prescriptionImages
                                .length}'),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: prescriptionImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              8),
                                          child: Image.memory(
                                            prescriptionImages[index],
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                stackTrace) =>
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius: BorderRadius
                                                        .circular(8),
                                                  ),
                                                  child: Icon(Icons.image,
                                                      color: Colors.grey[600],
                                                      size: 32),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                prescriptionImages.removeAt(
                                                    index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close,
                                                  color: Colors.white,
                                                  size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            StatefulBuilder(
              builder: (context, setButtonState) {
                bool isUploading = false;
                String progressText = '';
                return ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                    if (formKey.currentState!.validate()) {
                      setButtonState(() {
                        isUploading = true;
                        progressText = prescriptionImages.isNotEmpty
                            ? 'Uploading images...'
                            : 'Adding patient...';
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      try {
                        // Show modal loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx2) =>
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(progressText,
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ],
                              ),
                        );
                        // Actually add patient (this does image upload & referral creation)
                        final success = await context
                            .read<AdminFirebaseService>()
                            .addPatientReferral(
                          patientName: patientNameController.text,
                          age: int.tryParse(ageController.text) ?? 0,
                          contactInfo: contactInfoController.text,
                          address: addressController.text,
                          problem: problemController.text,
                          preferredTime: preferredDateTime != null
                              ? '${preferredDateTime!.hour.toString().padLeft(
                              2, '0')}:${preferredDateTime!
                              .minute
                              .toString()
                              .padLeft(2, '0')}'
                              : 'Flexible',
                          preferredDateTime: preferredDateTime,
                          doctorId: 'admin',
                          doctorName: doctorNameController.text,
                          notes: '',
                          prescriptionImages: prescriptionImages.isNotEmpty
                              ? prescriptionImages
                              : null,
                        );
                        if (!mounted) return;
                        Navigator
                            .of(context, rootNavigator: true)
                            .pop(); // close loading dialog
                        setButtonState(() {
                          isUploading = false;
                          progressText = '';
                        });
                        if (success) {
                          navigator.pop(); // Close dialog
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Patient ${patientNameController
                                      .text} added successfully with ${prescriptionImages
                                      .length} prescription images'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Failed to add patient. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.of(context, rootNavigator: true).pop();
                        setButtonState(() {
                          isUploading = false;
                          progressText = '';
                        });
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Error adding patient: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUploading ? Colors.grey : Colors
                        .blue[600],
                    foregroundColor: Colors.white,
                  ),
                  child: isUploading
                      ? Row(
                    children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )),
                      const SizedBox(width: 12),
                      Text(progressText.isNotEmpty
                          ? progressText
                          : 'Uploading...'),
                    ],
                  )
                      : const Text('Add Patient'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignPatient(BuildContext context, AdminPatient patient,
      AdminFirebaseService firebaseService) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final therapists = await firebaseService.getAvailableTherapists();
      Navigator.of(context).pop(); // Close loading

      if (therapists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No approved therapists available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final selectedTherapist = await showDialog<AdminUser>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: Text('Assign ${patient.patientName}'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: therapists.length,
                  itemBuilder: (context, index) {
                    final therapist = therapists[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Icon(Icons.healing, color: Colors.green[700]),
                        ),
                        title: Text(therapist.name, style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                        subtitle: Text(therapist.specialization),
                        onTap: () => Navigator.of(ctx).pop(therapist),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'))
              ],
            ),
      );

      if (selectedTherapist != null) {
        final success = await firebaseService.assignPatientToTherapist(
          patientId: patient.id,
          therapistId: selectedTherapist.uid,
          therapistName: selectedTherapist.name,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${patient.patientName} assigned to ${selectedTherapist
                      .name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reassignPatient(BuildContext context, AdminPatient patient,
      AdminFirebaseService firebaseService) async {
    await _assignPatient(context, patient, firebaseService);
  }

  void _viewPatientDetails(BuildContext context, AdminPatient patient) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: Text(patient.patientName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age: ${patient.age} years'),
                  Text('Contact: ${patient.contactInfo}'),
                  Text('Address: ${patient.address}'),
                  Text('Problem: ${patient.problem}'),
                  Text('Preferred Time: ${patient.preferredTime}'),
                  Text('Doctor: ${patient.doctorName}'),
                  if (patient.therapistName != null)
                    Text('Therapist: ${patient.therapistName}'),
                  Text('Status: ${patient.statusDisplayName}'),
                  const SizedBox(height: 20),
                  _buildPrescriptionImagesSection(context, patient),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}