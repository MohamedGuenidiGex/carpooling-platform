import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../providers/admin_analytics_provider.dart';

/// Analytics Screen - Detailed System Statistics
///
/// Shows real-time analytics data fetched from the backend.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.active,
    required this.completed,
    required this.cancelled,
  });

  final int? active;
  final int? completed;
  final int? cancelled;

  @override
  Widget build(BuildContext context) {
    if (active == null || completed == null || cancelled == null) {
      return const _EmptyChartPlaceholder();
    }

    final total = (active! + completed! + cancelled!).toDouble();
    if (total <= 0) {
      return const _EmptyChartPlaceholder();
    }

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: active!.toDouble(),
        color: Colors.blue,
        radius: 22,
        title: '',
      ),
      PieChartSectionData(
        value: completed!.toDouble(),
        color: Colors.green,
        radius: 22,
        title: '',
      ),
      PieChartSectionData(
        value: cancelled!.toDouble(),
        color: Colors.orange,
        radius: 22,
        title: '',
      ),
    ];

    Widget legendRow(String label, int value, Color color) {
      final pct = ((value / total) * 100).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.black,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              legendRow('Active', active!, Colors.blue),
              legendRow('Completed', completed!, Colors.green),
              legendRow('Cancelled', cancelled!, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtleSectionLabel extends StatelessWidget {
  const _SubtleSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _refreshSpinning = false;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    // Fetch analytics on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAnalyticsProvider>().fetchDashboardAnalytics();
    });
  }

  Future<void> _refresh(AdminAnalyticsProvider provider) async {
    if (_refreshSpinning) return;
    setState(() {
      _refreshSpinning = true;
    });
    try {
      await provider.fetchDashboardAnalytics();
    } finally {
      if (mounted) {
        setState(() {
          _refreshSpinning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = context.watch<AdminAnalyticsProvider>();
    final analytics = analyticsProvider.analytics;
    final isLoading = analyticsProvider.isLoading;
    final errorMessage = analyticsProvider.errorMessage;

    final now = DateTime.now();
    final trends = analyticsProvider.trends;
    final statusDist = analyticsProvider.statusDistribution;

    final timeframeLabel = _selectedDays == 1
        ? 'Today'
        : _selectedDays == 7
        ? 'Last 7 days'
        : 'Last 30 days';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: BrandColors.white,
        elevation: 0,
        title: const Text(
          'Analytics',
          style: TextStyle(
            color: BrandColors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedDays,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  color: BrandColors.black,
                  fontWeight: FontWeight.w800,
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Today')),
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                ],
                onChanged: isLoading
                    ? null
                    : (v) async {
                        if (v == null || v == _selectedDays) return;
                        setState(() {
                          _selectedDays = v;
                        });
                        await analyticsProvider.fetchTrends(days: v);
                      },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: isLoading ? null : () => _refresh(analyticsProvider),
              icon: AnimatedRotation(
                turns: _refreshSpinning ? 1 : 0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.refresh,
                  color: isLoading ? Colors.grey[400] : BrandColors.black,
                ),
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    if (errorMessage != null)
                      _ErrorBanner(message: errorMessage),

                    _SectionHeader(
                      title: 'KPI Snapshot',
                      subtitle: 'Core system signals at a glance',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _KpiCard(
                      icon: Icons.people_outline,
                      color: BrandColors.primaryRed,
                      label: 'Total Users',
                      value: isLoading || analytics == null
                          ? null
                          : analytics.usersTotal.toDouble(),
                      microTrend: (isLoading || analytics == null)
                          ? null
                          : '+${analytics.usersToday} today',
                      spark: null,
                    ),
                    _KpiCard(
                      icon: Icons.directions_car_outlined,
                      color: Colors.blue,
                      label: 'Active Rides',
                      value: isLoading || analytics == null
                          ? null
                          : analytics.activeRides.toDouble(),
                      microTrend: null,
                      spark: null,
                    ),
                    _KpiCard(
                      icon: Icons.local_car_wash_outlined,
                      color: Colors.orange,
                      label: 'Total Rides',
                      value: isLoading || analytics == null
                          ? null
                          : analytics.ridesTotal.toDouble(),
                      microTrend: null,
                      spark: null,
                    ),
                    _KpiCard(
                      icon: Icons.bookmark_outline,
                      color: Colors.purple,
                      label: 'Reservations',
                      value: isLoading || analytics == null
                          ? null
                          : analytics.reservationsTotal.toDouble(),
                      microTrend: null,
                      spark: null,
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubtleSectionLabel('Live Metrics'),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Main Analytics',
                      subtitle: 'Trends and distribution',
                    ),
                    const SizedBox(height: 12),

                    _ChartCard(
                      title: 'Ride Activity Trend',
                      subtitle: 'Rides created over time • $timeframeLabel',
                      child: _LineChart(
                        color: Colors.blue,
                        values: (trends == null)
                            ? null
                            : trends.ridesPerDay
                                  .map((e) => e.count.toDouble())
                                  .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: 'User Growth',
                      subtitle:
                          'Employee registrations over time • $timeframeLabel',
                      child: _BarChart(
                        color: BrandColors.success,
                        values: (trends == null)
                            ? null
                            : trends.userGrowthPerDay
                                  .map((e) => e.count.toDouble())
                                  .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: 'Ride Status Distribution',
                      subtitle: 'Current distribution',
                      child: _DonutChart(
                        active: statusDist?.active,
                        completed: statusDist?.completed,
                        cancelled: statusDist?.cancelled,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TopRoutesCard(
                      routes: analyticsProvider.topRoutes,
                      isLoading: isLoading,
                      onFilterChanged: (country) {
                        analyticsProvider.fetchTopRoutesFiltered(
                          country: country,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: 'Reservation Funnel',
                      subtitle: 'Conversion through reservation lifecycle',
                      child: _ReservationFunnelChart(
                        funnel: analyticsProvider.reservationFunnel,
                        isLoading: isLoading,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: BrandColors.primaryRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.microTrend,
    required this.spark,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double? value;
  final String? microTrend;
  final List<double>? spark;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final trendText = widget.microTrend;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.08 : 0.04),
              blurRadius: _pressed ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            if (widget.spark != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.16,
                  child: _Sparkline(color: widget.color, values: widget.spark!),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 18),
                    ),
                    const Spacer(),
                    if (trendText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          trendText,
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                _CountUpNumber(value: widget.value, color: BrandColors.black),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountUpNumber extends StatelessWidget {
  const _CountUpNumber({required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Container(
        height: 28,
        width: 70,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value!),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v.round().toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.color, required this.values});

  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (values.isEmpty ? 0 : (values.length - 1)).toDouble(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: BrandColors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: child),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.color, required this.values});

  final Color color;
  final List<double>? values;

  @override
  Widget build(BuildContext context) {
    if (values == null || values!.isEmpty) {
      return const _EmptyChartPlaceholder();
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < values!.length; i++) {
      spots.add(FlSpot(i.toDouble(), values![i]));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.black.withOpacity(0.06), strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.color, required this.values});

  final Color color;
  final List<double>? values;

  @override
  Widget build(BuildContext context) {
    if (values == null || values!.isEmpty) {
      return const _EmptyChartPlaceholder();
    }

    final maxY = values!.reduce((a, b) => a > b ? a : b) + 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.black.withOpacity(0.06), strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < values!.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values![i],
                  color: color,
                  width: 12,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: color.withOpacity(0.12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SystemStatusPanel extends StatelessWidget {
  const _SystemStatusPanel({
    required this.statusText,
    required this.isHealthy,
    required this.lastUpdated,
  });

  final String statusText;
  final bool isHealthy;
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final statusColor = isHealthy ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(14),
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
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: BrandColors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Updated ${_timeAgo(lastUpdated)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Not available yet',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _TopRoutesCard extends StatefulWidget {
  const _TopRoutesCard({
    required this.routes,
    required this.isLoading,
    required this.onFilterChanged,
  });

  final List<Map<String, dynamic>>? routes;
  final bool isLoading;
  final Function(String?) onFilterChanged;

  @override
  State<_TopRoutesCard> createState() => _TopRoutesCardState();
}

class _TopRoutesCardState extends State<_TopRoutesCard> {
  String? _selectedCountry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Routes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BrandColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Most frequent origin → destination pairs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterButton(
                label: 'All',
                isSelected: _selectedCountry == null,
                onTap: () {
                  setState(() => _selectedCountry = null);
                  widget.onFilterChanged(null);
                },
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Tunisia',
                isSelected: _selectedCountry == 'tunisia',
                onTap: () {
                  setState(() => _selectedCountry = 'tunisia');
                  widget.onFilterChanged('tunisia');
                },
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'France',
                isSelected: _selectedCountry == 'france',
                onTap: () {
                  setState(() => _selectedCountry = 'france');
                  widget.onFilterChanged('france');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _TopRoutesList(
              routes: widget.routes,
              isLoading: widget.isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? BrandColors.primaryRed : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? BrandColors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _TopRoutesList extends StatelessWidget {
  const _TopRoutesList({required this.routes, required this.isLoading});

  final List<Map<String, dynamic>>? routes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading || routes == null) {
      return const _EmptyChartPlaceholder();
    }

    if (routes!.isEmpty) {
      return Center(
        child: Text(
          'No route data available',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Column(
      children: routes!.take(3).toList().asMap().entries.map((entry) {
        final index = entry.key;
        final route = entry.value;
        final origin = route['origin']?.toString() ?? 'Unknown';
        final destination = route['destination']?.toString() ?? 'Unknown';
        final rides = route['rides'] as int? ?? 0;

        return Padding(
          padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: BrandColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: BrandColors.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      origin,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destination,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$rides rides',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReservationFunnelChart extends StatelessWidget {
  const _ReservationFunnelChart({
    required this.funnel,
    required this.isLoading,
  });

  final Map<String, dynamic>? funnel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading || funnel == null) {
      return const _EmptyChartPlaceholder();
    }

    final requested = funnel!['requested'] as int? ?? 0;
    final confirmed = funnel!['confirmed'] as int? ?? 0;
    final boarded = funnel!['boarded'] as int? ?? 0;

    if (requested == 0 && confirmed == 0 && boarded == 0) {
      return Center(
        child: Text(
          'No reservation data available',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    final maxValue = requested > 0 ? requested : 1;

    Widget funnelBar(String label, int value, Color color) {
      final percentage = (value / maxValue * 100).round();
      final width = value / maxValue;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.black,
                  ),
                ),
                Text(
                  '$value ($percentage%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 24,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * width,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        funnelBar('Requested', requested, BrandColors.primaryRed),
        funnelBar('Confirmed', confirmed, BrandColors.darkRed),
        funnelBar('Boarded', boarded, BrandColors.success),
      ],
    );
  }
}
