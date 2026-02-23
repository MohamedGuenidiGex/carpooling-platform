import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/monitoring_overview.dart';
import '../providers/admin_monitoring_provider.dart';
import '../widgets/admin_drawer.dart';
import 'analytics_screen.dart';
import 'user_management_screen.dart';

/// Admin Dashboard Screen - Modern Monitoring Console
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminMonitoringProvider>().fetchMonitoringOverview();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<AdminMonitoringProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final monitoringProvider = context.watch<AdminMonitoringProvider>();
    final overview = monitoringProvider.overview;
    final isLoading = monitoringProvider.isLoading;
    final errorMessage = monitoringProvider.errorMessage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: BrandColors.primaryRed,
          backgroundColor: BrandColors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _TopBar(
                    userName: user?.displayName ?? 'Admin User',
                    systemStatus: overview?.systemHealth.status ?? 'unknown',
                    isHealthy: overview?.systemHealth.isOperational ?? false,
                    isLoading: isLoading,
                  ),
                ),
              ),
              if (errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ErrorBanner(message: errorMessage),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _SystemHealthCard(
                    health: overview?.systemHealth,
                    isLoading: isLoading,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _LiveMetricCard(
                      icon: Icons.directions_car_outlined,
                      label: 'Active Rides Now',
                      value: overview?.liveMetrics.activeRidesNow ?? 0,
                      color: Colors.blue,
                      isLoading: isLoading,
                    ),
                    _LiveMetricCard(
                      icon: Icons.people_outline,
                      label: 'Online Users',
                      value: overview?.liveMetrics.onlineUsers ?? 0,
                      color: BrandColors.primaryRed,
                      isLoading: isLoading,
                    ),
                    _LiveMetricCard(
                      icon: Icons.pending_actions_outlined,
                      label: 'Pending Requests',
                      value: overview?.liveMetrics.pendingRequests ?? 0,
                      color: Colors.orange,
                      isLoading: isLoading,
                      microIndicator:
                          overview?.liveMetrics.pendingRequests != null &&
                              overview!.liveMetrics.pendingRequests > 0
                          ? 'needs attention'
                          : null,
                    ),
                    _LiveMetricCard(
                      icon: Icons.devices_outlined,
                      label: 'Active Sessions',
                      value: overview?.liveMetrics.activeSessions ?? 0,
                      color: Colors.purple,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: _SectionTitle(title: 'Control Center'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ControlCard(
                    icon: Icons.manage_accounts_outlined,
                    title: 'User Management',
                    description: 'Manage employees and permissions',
                    accentColor: BrandColors.primaryRed,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserManagementScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _ControlCard(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics',
                    description: 'View statistics and trends',
                    accentColor: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: _SectionTitle(title: 'Recent System Events'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _RecentEventsList(
                    events: overview?.recentEvents ?? [],
                    isLoading: isLoading,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.userName,
    required this.systemStatus,
    required this.isHealthy,
    required this.isLoading,
  });

  final String userName;
  final String systemStatus;
  final bool isHealthy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: BrandColors.black, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _StatusIndicator(
            status: isLoading ? 'loading' : systemStatus,
            isHealthy: isHealthy,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.status,
    required this.isHealthy,
    required this.isLoading,
  });

  final String status;
  final bool isHealthy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseDot(isHealthy: isHealthy, isLoading: isLoading),
        const SizedBox(width: 8),
        Text(
          isLoading ? 'Loading...' : (isHealthy ? 'Operational' : status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isLoading
                ? Colors.grey[500]
                : (isHealthy ? Colors.green : Colors.orange),
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.isHealthy, required this.isLoading});

  final bool isHealthy;
  final bool isLoading;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLoading
        ? Colors.grey
        : (widget.isHealthy ? Colors.green : Colors.orange);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: widget.isHealthy
                ? [
                    BoxShadow(
                      color: color.withAlpha(
                        (0.4 * _animation.value * 255).round(),
                      ),
                      blurRadius: 8 * _animation.value,
                      spreadRadius: 2 * _animation.value,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class _SystemHealthCard extends StatefulWidget {
  const _SystemHealthCard({required this.health, required this.isLoading});

  final SystemHealth? health;
  final bool isLoading;

  @override
  State<_SystemHealthCard> createState() => _SystemHealthCardState();
}

class _SystemHealthCardState extends State<_SystemHealthCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isHealthy = widget.health?.isOperational ?? false;
    final isDegraded = widget.health?.isDegraded ?? false;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDegraded
              ? const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [BrandColors.primaryRed, BrandColors.darkRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (isDegraded ? Colors.orange : BrandColors.primaryRed)
                  .withAlpha(((_pressed ? 0.35 : 0.25) * 255).round()),
              blurRadius: _pressed ? 18 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHealthy
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Status',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      widget.isLoading
                          ? Container(
                              height: 20,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(76),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              widget.health?.message ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.isLoading
                    ? 'Updating...'
                    : 'Last updated: ${widget.health?.lastUpdated != null ? _timeAgo(widget.health!.lastUpdated) : 'never'}',
                style: TextStyle(
                  color: Colors.white.withAlpha(178),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return 'unknown';
    }
  }
}

class _LiveMetricCard extends StatefulWidget {
  const _LiveMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isLoading,
    this.microIndicator,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool isLoading;
  final String? microIndicator;

  @override
  State<_LiveMetricCard> createState() => _LiveMetricCardState();
}

class _LiveMetricCardState extends State<_LiveMetricCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (!widget.isLoading) _controller.forward();
  }

  @override
  void didUpdateWidget(_LiveMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !widget.isLoading) {
      _animation = Tween<double>(begin: 0, end: widget.value.toDouble())
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                ((_pressed ? 0.08 : 0.04) * 255).round(),
              ),
              blurRadius: _pressed ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const Spacer(),
                if (widget.microIndicator != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.microIndicator!,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (widget.isLoading)
              Container(
                height: 28,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            else
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Text(
                  _animation.value.round().toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BrandColors.black,
                    height: 1,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: BrandColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: BrandColors.black,
          ),
        ),
      ],
    );
  }
}

class _ControlCard extends StatefulWidget {
  const _ControlCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends State<_ControlCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                (((_pressed ? 0.08 : 0.04) * 255)).round(),
              ),
              blurRadius: _pressed ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}

class _RecentEventsList extends StatelessWidget {
  const _RecentEventsList({required this.events, required this.isLoading});

  final List<SystemEvent> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(BrandColors.primaryRed),
            ),
          ),
        ),
      );
    }

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.history_toggle_off, color: Colors.grey[500], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent system events',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            _EventItem(event: events[i]),
            if (i < events.length - 1)
              Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          ],
        ],
      ),
    );
  }
}

class _EventItem extends StatelessWidget {
  const _EventItem({required this.event});

  final SystemEvent event;

  @override
  Widget build(BuildContext context) {
    final icon = _getEventIcon(event.eventType);
    final color = _getSeverityColor(event.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(event.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    final type = eventType.toUpperCase();
    if (type.contains('USER')) return Icons.person_outline;
    if (type.contains('RIDE')) return Icons.directions_car_outlined;
    if (type.contains('RESERVATION')) return Icons.bookmark_outline;
    if (type.contains('SYSTEM')) return Icons.settings_outlined;
    if (type.contains('LOCK')) return Icons.lock_outline;
    if (type.contains('CANCEL')) return Icons.cancel_outlined;
    return Icons.info_outline;
  }

  Color _getSeverityColor(String severity) {
    final s = severity.toUpperCase();
    if (s == 'CRITICAL') return Colors.red;
    if (s == 'WARNING') return Colors.orange;
    return Colors.blue;
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
