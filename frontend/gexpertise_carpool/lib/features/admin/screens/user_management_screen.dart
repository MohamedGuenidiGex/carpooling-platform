import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../providers/admin_provider.dart';
import 'admin_user_details_screen.dart';

/// User Management Screen - Admin interface for managing users
///
/// Features search functionality, user list with status chips,
/// and ability to toggle user status between active and frozen.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Management',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BrandColors.black),
            onPressed: () => context.read<AdminProvider>().fetchUsers(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            // User List
            Expanded(
              child: Consumer<AdminProvider>(
                builder: (context, adminProvider, child) {
                  if (adminProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: BrandColors.primaryRed,
                      ),
                    );
                  }

                  if (adminProvider.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            adminProvider.errorMessage!,
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => adminProvider.fetchUsers(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BrandColors.primaryRed,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredUsers = adminProvider.getFilteredUsers(
                    _searchController.text,
                  );

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No users found'
                                : 'No users matching "${_searchController.text}"',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _buildUserCard(user, adminProvider);
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    AdminProvider adminProvider,
  ) {
    final userId = user['id'] as int? ?? 0;
    final name = (user['name'] ?? 'Unknown').toString();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? 'employee').toString();
    final status = (user['status'] ?? 'active').toString();
    final isActive = status == 'active';

    // Get initials from name
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((n) => n.isNotEmpty ? n[0] : '')
              .join('')
              .toUpperCase()
              .substring(0, name.split(' ').length > 1 ? 2 : 1)
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? BrandColors.primaryRed.withOpacity(0.1)
              : Colors.grey[300],
          foregroundColor: isActive ? BrandColors.primaryRed : Colors.grey[600],
          child: Text(
            initials,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: BrandColors.black,
          ),
        ),
        subtitle: Text(
          '$email • ${role.toUpperCase()}',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.green[200]! : Colors.red[200]!,
                ),
              ),
              child: Text(
                isActive ? 'Active' : 'Frozen',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Toggle Button
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red[400] : Colors.green[500],
              ),
              onPressed: () => _showToggleConfirmation(
                userId,
                name,
                isActive,
                adminProvider,
              ),
              tooltip: isActive ? 'Freeze User' : 'Activate User',
            ),
            // View Details Button
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: BrandColors.primaryRed,
                size: 22,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminUserDetailsScreen(userId: userId),
                  ),
                );
              },
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleConfirmation(
    int userId,
    String name,
    bool isActive,
    AdminProvider adminProvider,
  ) {
    final action = isActive ? 'freeze' : 'activate';
    final newStatus = isActive ? 'frozen' : 'active';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm ${action.toUpperCase()}'),
        content: Text('Are you sure you want to $action $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await adminProvider.toggleUserStatus(
                userId,
                newStatus,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User $action successfully'),
                    backgroundColor: isActive
                        ? Colors.red[600]
                        : Colors.green[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red[600] : Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
