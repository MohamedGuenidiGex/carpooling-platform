import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/network/api_client.dart';

/// Admin User Details Screen - View employee profile and activity timeline
class AdminUserDetailsScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailsScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  bool _isLoadingProfile = true;
  bool _isLoadingActivity = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _activities = [];
  int _activityOffset = 0;
  final int _activityLimit = 20;
  bool _hasMoreActivities = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserActivity();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get('/admin/users/${widget.userId}');
      setState(() {
        _userProfile = response;
        _isLoadingProfile = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user profile: $e';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserActivity() async {
    setState(() {
      _isLoadingActivity = true;
    });

    try {
      final response = await ApiClient.get(
        '/admin/users/${widget.userId}/activity?limit=$_activityLimit&offset=0',
      );
      // Handle response as List directly
      final List<dynamic> rawList = response is List ? response : [];
      final activities = rawList
          .map((item) => item as Map<String, dynamic>)
          .toList();

      setState(() {
        _activities = activities;
        _activityOffset = activities.length;
        _hasMoreActivities = activities.length == _activityLimit;
        _isLoadingActivity = false;
      });
    } catch (e) {
      debugPrint('Error loading activity: $e');
      setState(() {
        _isLoadingActivity = false;
      });
    }
  }

  Future<void> _loadMoreActivity() async {
    if (_isLoadingMore || !_hasMoreActivities) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ApiClient.get(
        '/admin/users/${widget.userId}/activity?limit=$_activityLimit&offset=$_activityOffset',
      );
      // Handle response as List directly
      final List<dynamic> rawList = response is List ? response : [];
      final activities = rawList
          .map((item) => item as Map<String, dynamic>)
          .toList();

      setState(() {
        _activities.addAll(activities);
        _activityOffset += activities.length;
        _hasMoreActivities = activities.length == _activityLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more activity: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _activityOffset = 0;
      _hasMoreActivities = true;
    });
    await Future.wait([_loadUserProfile(), _loadUserActivity()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: BrandColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Employee Details',
          style: TextStyle(
            color: BrandColors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BrandColors.black),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: BrandColors.primaryRed,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(BrandColors.primaryRed),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userProfile == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 16),
          if (_userProfile!['car'] != null) ...[
            _buildCarSection(),
            const SizedBox(height: 16),
          ],
          _buildStatsSection(),
          const SizedBox(height: 16),
          _buildActivitySection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final name = _userProfile!['name']?.toString() ?? 'Unknown';
    final email = _userProfile!['email']?.toString() ?? '';
    final status = _userProfile!['status']?.toString() ?? 'active';
    final department = _userProfile!['department']?.toString();
    final phoneNumber = _userProfile!['phone_number']?.toString();
    final createdAt = _userProfile!['created_at']?.toString();
    final lastLogin = _userProfile!['last_login']?.toString();

    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((n) => n.isNotEmpty ? n[0] : '')
              .join('')
              .toUpperCase()
              .substring(0, name.split(' ').length > 1 ? 2 : 1)
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: BrandColors.primaryRed.withOpacity(0.1),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: BrandColors.primaryRed,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: BrandColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'active'
                  ? BrandColors.success.withOpacity(0.1)
                  : BrandColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status == 'active'
                    ? BrandColors.success.withOpacity(0.3)
                    : BrandColors.error.withOpacity(0.3),
              ),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status == 'active'
                    ? BrandColors.success
                    : BrandColors.error,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (department != null)
            _buildInfoRow(Icons.business_outlined, 'Department', department),
          if (phoneNumber != null)
            _buildInfoRow(Icons.phone_outlined, 'Phone', phoneNumber),
          if (createdAt != null)
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Account Created',
              _formatDate(createdAt),
            ),
          if (lastLogin != null)
            _buildInfoRow(
              Icons.login_outlined,
              'Last Login',
              _formatDate(lastLogin),
            ),
        ],
      ),
    );
  }

  Widget _buildCarSection() {
    final car = _userProfile!['car'] as Map<String, dynamic>;
    final model = car['model']?.toString() ?? 'Unknown';
    final color = car['color']?.toString() ?? 'Unknown';
    final licensePlate = car['license_plate']?.toString() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: BrandColors.primaryRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Car Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.car_rental, 'Model', model),
          _buildInfoRow(Icons.palette_outlined, 'Color', color),
          _buildInfoRow(Icons.pin_outlined, 'License Plate', licensePlate),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final ridesOffered = _userProfile!['rides_offered'] as int? ?? 0;
    final reservationsMade = _userProfile!['reservations_made'] as int? ?? 0;
    final completedTrips = _userProfile!['completed_trips'] as int? ?? 0;
    final cancelledTrips = _userProfile!['cancelled_trips'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BrandColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Rides Offered',
                  ridesOffered.toString(),
                  Icons.directions_car_outlined,
                  BrandColors.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Reservations',
                  reservationsMade.toString(),
                  Icons.bookmark_outline,
                  BrandColors.darkRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedTrips.toString(),
                  Icons.check_circle_outline,
                  BrandColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Cancelled',
                  cancelledTrips.toString(),
                  Icons.cancel_outlined,
                  BrandColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.darkGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BrandColors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingActivity)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    BrandColors.primaryRed,
                  ),
                ),
              ),
            )
          else if (_activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      color: Colors.grey[300],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No activity recorded',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ..._activities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final activity = entry.value;
                  return Column(
                    children: [
                      _buildActivityItem(activity),
                      if (index < _activities.length - 1)
                        Divider(height: 1, color: Colors.grey[200]),
                    ],
                  );
                }),
                if (_hasMoreActivities)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              BrandColors.primaryRed,
                            ),
                          )
                        : TextButton(
                            onPressed: _loadMoreActivity,
                            child: const Text(
                              'Load More',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type']?.toString() ?? '';
    final description = activity['description']?.toString() ?? '';
    final timestamp = activity['timestamp']?.toString() ?? '';
    final rideId = activity['ride_id'] as int?;
    final reservationId = activity['reservation_id'] as int?;

    final icon = _getActivityIcon(type);
    final color = _getActivityColor(type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (rideId != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        'Ride #$rideId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (reservationId != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        'Reservation #$reservationId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    final t = type.toUpperCase();
    if (t.contains('RIDE') && t.contains('START'))
      return Icons.play_circle_outline;
    if (t.contains('RIDE') && t.contains('COMPLET'))
      return Icons.check_circle_outline;
    if (t.contains('RIDE') && t.contains('CREAT'))
      return Icons.add_circle_outline;
    if (t.contains('RIDE') && t.contains('CANCEL'))
      return Icons.cancel_outlined;
    if (t.contains('RESERVATION') && t.contains('CONFIRM'))
      return Icons.bookmark;
    if (t.contains('RESERVATION') && t.contains('REQUEST'))
      return Icons.bookmark_outline;
    if (t.contains('RESERVATION') && t.contains('CANCEL'))
      return Icons.bookmark_remove;
    if (t.contains('BOARD')) return Icons.gps_fixed;
    if (t.contains('LOGIN')) return Icons.login;
    return Icons.info_outline;
  }

  Color _getActivityColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('COMPLET') || t.contains('CONFIRM'))
      return BrandColors.success;
    if (t.contains('CANCEL')) return BrandColors.error;
    if (t.contains('START') || t.contains('CREAT'))
      return BrandColors.primaryRed;
    if (t.contains('REQUEST')) return BrandColors.darkRed;
    return BrandColors.primaryRed;
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }
}
