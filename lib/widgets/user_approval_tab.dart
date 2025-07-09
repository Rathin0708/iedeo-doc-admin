import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';
import '../models/admin_user.dart';

class UserApprovalTab extends StatelessWidget {
  const UserApprovalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFirebaseService>(
      builder: (context, firebaseService, child) {
        if (firebaseService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingUsers = firebaseService.pendingUsers;

        return Column(
          children: [
            // Sticky Pending Summary Card
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange[50]!, Colors.orange[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange[400]!, Colors.orange[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Approvals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pendingUsers.length} users awaiting approval',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[600],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${pendingUsers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Users List
            Expanded(
              child: pendingUsers.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Approvals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All user registrations have been processed',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  return _buildUserCard(context, user, firebaseService);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserCard(BuildContext context,
      AdminUser user,
      AdminFirebaseService firebaseService,) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange[700],
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

            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(user.address)),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _rejectUser(context, user, firebaseService),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
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
        ),
      ),
    );
  }

  Future<void> _approveUser(BuildContext context,
      AdminUser user,
      AdminFirebaseService firebaseService,) async {
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

  Future<void> _rejectUser(BuildContext context,
      AdminUser user,
      AdminFirebaseService firebaseService,) async {
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
}