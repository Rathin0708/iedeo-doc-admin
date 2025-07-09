import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';
import '../models/admin_user.dart';

class UsersManagementTab extends StatefulWidget {
  const UsersManagementTab({super.key});

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFirebaseService>(
      builder: (context, firebaseService, child) {
        if (firebaseService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allUsers = firebaseService.allUsers;
        final filteredUsers = _filterUsers(allUsers);

        return Column(
          children: [
            // Sticky Search and Filter Controls
            Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search users by name or email...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red[700]!),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Filter Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                value: _selectedRole,
                                items: ['All', 'Doctor', 'Therapist']
                                    .map((role) =>
                                    DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRole = value!;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                value: _selectedStatus,
                                items: [
                                  'All',
                                  'Approved',
                                  'Pending',
                                  'Rejected'
                                ]
                                    .map((status) =>
                                    DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Results Count
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${filteredUsers.length} users found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Users List
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or filters',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                      ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserCard(context, user, firebaseService);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<AdminUser> _filterUsers(List<AdminUser> users) {
    return users.where((user) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          user.name.toLowerCase().contains(_searchQuery) ||
          user.email.toLowerCase().contains(_searchQuery);

      // Role filter
      final matchesRole = _selectedRole == 'All' ||
          (_selectedRole == 'Doctor' && user.isDoctor) ||
          (_selectedRole == 'Therapist' && !user.isDoctor);

      // Status filter
      final matchesStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Approved' && user.isApproved) ||
          (_selectedStatus == 'Pending' && user.isPending) ||
          (_selectedStatus == 'Rejected' && user.isRejected);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Widget _buildUserCard(BuildContext context, AdminUser user,
      AdminFirebaseService firebaseService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with role and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: user.isDoctor ? Colors.blue[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.isDoctor ? Icons.medical_services : Icons.healing,
                        size: 16,
                        color: user.isDoctor ? Colors.blue[700] : Colors
                            .green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.roleDisplayName,
                        style: TextStyle(
                          color: user.isDoctor ? Colors.blue[700] : Colors
                              .green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: user.isApproved
                        ? Colors.green[100]
                        : user.isPending
                        ? Colors.orange[100]
                        : Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.statusDisplayName.toUpperCase(),
                    style: TextStyle(
                      color: user.isApproved
                          ? Colors.green[700]
                          : user.isPending
                          ? Colors.orange[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User Information
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(user.email)),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(user.phone),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('License: ${user.licenseNumber}'),
              ],
            ),

            if (user.specialization.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.school, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Specialization: ${user.specialization}'),
                ],
              ),
            ],

            // Action buttons for non-approved users
            if (!user.isApproved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (user.isPending) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _approveUser(context, user, firebaseService),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                      user.isPending
                          ? _rejectUser(context, user, firebaseService)
                          : _deleteUser(context, user, firebaseService),
                      icon: Icon(
                        user.isPending ? Icons.close : Icons.delete,
                        size: 18,
                      ),
                      label: Text(user.isPending ? 'Reject' : 'Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveUser(BuildContext context, AdminUser user,
      AdminFirebaseService firebaseService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Approve User'),
            content: Text('Are you sure you want to approve ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await firebaseService.approveUser(user.uid);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, AdminUser user,
      AdminFirebaseService firebaseService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Reject User'),
            content: Text('Are you sure you want to reject ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await firebaseService.rejectUser(user.uid);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, AdminUser user,
      AdminFirebaseService firebaseService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Delete User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete ${user.name}?'),
                const SizedBox(height: 8),
                const Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Note: You'll need to implement deleteUser method in AdminFirebaseService
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete functionality not yet implemented'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}