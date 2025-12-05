import 'package:brainq_app/providers/admin_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _selectedDateRange = 'Last 7 Days';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDashboard());
  }

  Future<void> _fetchDashboard() async {
    final admin = context.read<AdminProvider>();
    Map<String, String> queryParams = {};
    final now = DateTime.now();

    if (_selectedDateRange == 'Custom' && _customRange != null) {
      queryParams['start'] = _customRange!.start.toIso8601String();
      queryParams['end'] = _customRange!.end.toIso8601String();
    } else {
      switch (_selectedDateRange) {
        case 'Last 7 Days':
          queryParams['range'] = '7';
          break;
        case 'Last 30 Days':
          queryParams['range'] = '30';
          break;
        case 'Last 60 Days':
          queryParams['range'] = '60';
          break;
        case 'This Month':
          queryParams['range'] = 'this_month';
          break;
        case 'All Time':
        default:
          queryParams['start'] = DateTime(2000).toIso8601String();
          queryParams['end'] = now.toIso8601String();
          break;
      }
    }

    await admin.fetchDashboardStats(queryParams: queryParams);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedDateRange = 'Custom';
      });
      _fetchDashboard();
    }
  }

  Future<void> _refresh() async => _fetchDashboard();

  Widget _buildStatCard(String title, String value, Color color,
      {IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Adaptive colors
    final backgroundColor = isDark
        ? color.withValues(alpha:0.2) 
        : color.withValues(alpha:0.15);

    final textColor = isDark
        ? Colors.white
        : Colors.black87;

    final iconColor = isDark
        ? Colors.white
        : color;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: backgroundColor,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textColor)),
          ],
        ),
      ),
    );
  }

  // ----------------- Bar Chart Screen -----------------
  Widget _buildBarChartScreen(List<dynamic> data, String label, Color barColor,
      {String valueKey = 'count', String labelKey = 'label'}) {
    if (data.isEmpty) return const SizedBox.shrink();

    final barGroups = data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: (e.value[valueKey] ?? 0).toDouble(),
            color: barColor,
            width: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    final xLabels = data.map((d) => d[labelKey]?.toString() ?? '').toList();
    final maxY =
        (data.map((d) => (d[valueKey] ?? 0) as int).fold<int>(0, (prev, curr) => curr > prev ? curr : prev) + 2).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < xLabels.length) {
                      return Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          xLabels[index].length > 10
                              ? '${xLabels[index].substring(0, 10)}...'
                              : xLabels[index],
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(show: true),
          ),
        ),
      ),
    );
  }


  // ----------------- Line Chart Screen -----------------
  Widget _buildLineChartScreen(List<dynamic> data, String label,
      {String valueKey = 'count', String labelKey = 'label', Color lineColor = Colors.blue}) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value[valueKey] ?? 0).toDouble());
    }).toList();

    final xLabels = data.map((d) => d[labelKey]?.toString() ?? '').toList();
    final maxY =
        (data.map((d) => (d[valueKey] ?? 0) as int).fold<int>(0, (prev, curr) => curr > prev ? curr : prev) + 2).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < xLabels.length) {
                      return Text(xLabels[index],
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(show: true),
          ),
        ),
      ),
    );
  }

  // ----------------- List Section -----------------
  Widget _buildListSection(String title, List<dynamic> items, {bool isUser = true}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: isUser
                  ? CircleAvatar(child: Text(item['username']?[0]?.toUpperCase() ?? '?'))
                  : CircleAvatar(child: Text(item['owner__username']?[0]?.toUpperCase() ?? '?')),
              title: Text(isUser ? item['username'] ?? '' : item['owner__username'] ?? 'Unknown'),
              subtitle: Text(isUser
                  ? item['email'] ?? ''
                  : 'Decks Created: ${item['deck_count'] ?? 0}'),
              trailing: isUser ? null : const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------- Main Build -----------------
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(builder: (context, admin, _) {
      final stats = admin.dashboardStats ?? {};
      final usersStats = stats['users'] ?? {};
      final decksStats = stats['decks'] ?? {};
      final quizStats = stats['quiz'] ?? {};
      final loading = admin.loadingDashboard;
      final error = admin.error;

      return Scaffold(
        appBar: AppBar(title: const Text("Admin Analytics")),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // Date Range Filter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            DropdownButton<String>(
                              value: _selectedDateRange,
                              onChanged: (val) {
                                if (val != null && val != 'Custom') {
                                  setState(() {
                                    _selectedDateRange = val;
                                    _customRange = null;
                                  });
                                  _fetchDashboard();
                                } else if (val == 'Custom') {
                                  _pickCustomRange();
                                }
                              },
                              items: [
                                'Last 7 Days',
                                'Last 30 Days',
                                'Last 60 Days',
                                'This Month',
                                'All Time',
                                'Custom'
                              ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Stats Cards
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatCard(
                                  "Total Users", usersStats['total']?.toString() ?? '-', Colors.blue,
                                  icon: Icons.people),
                              _buildStatCard(
                                  "Flagged Decks", decksStats['flagged']?.toString() ?? '0', Colors.redAccent,
                                  icon: Icons.report), // replaced Active Users
                              _buildStatCard(
                                  "Suspended Users", usersStats['suspended']?.toString() ?? '-', Colors.red,
                                  icon: Icons.block),
                              _buildStatCard(
                                  "Total Decks", decksStats['total']?.toString() ?? '-', Colors.orange,
                                  icon: Icons.folder),
                            ],
                          ),
                        ),


                        // Recent Users
                        _buildListSection("Recent Users", usersStats['recent'] ?? [], isUser: true),

                        // Top Deck Creators
                        _buildListSection("Top Deck Creators", decksStats['top_creators'] ?? [], isUser: false),

                        // Quiz Stats Summary
                        if (quizStats.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Quiz Stats",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Text("Total Sessions: ${quizStats['total_sessions'] ?? 0}"),
                                  Text("Completed Sessions: ${quizStats['completed_sessions'] ?? 0}"),
                                  Text("Average Accuracy: ${quizStats['avg_accuracy'] ?? 0}%"),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Charts Buttons
                        const SizedBox(height: 24),
                        Text("Charts",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        // Deck Types
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _buildBarChartScreen([
                                  {'label': 'Public', 'count': decksStats['public'] ?? 0},
                                  {'label': 'Private', 'count': decksStats['private'] ?? 0},
                                  {'label': 'Archived', 'count': decksStats['archived'] ?? 0},
                                ], 'Deck Types', Colors.orange),
                              ),
                            );
                          },
                          child: const Text("View Deck Types Chart"),
                        ),

                        // Deck Creation Trends
                        if (stats['deck_creations'] != null)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _buildLineChartScreen(
                                      stats['deck_creations'], "Decks Created Over Time",
                                      valueKey: 'count', labelKey: 'date', lineColor: Colors.orange),
                                ),
                              );
                            },
                            child: const Text("View Deck Creation Trends"),
                          ),

                        // Most Completed Decks
                        if (quizStats['popular_decks'] != null &&
                            (quizStats['popular_decks'] as List).isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _buildBarChartScreen(
                                      (quizStats['popular_decks'] as List)
                                          .map((d) => {'label': d['deck__title'], 'count': d['usage_count']})
                                          .toList(),
                                      "Most Completed Decks",
                                      Colors.green),
                                ),
                              );
                            },
                            child: const Text("View Most Completed Decks"),
                          ),
                      ],
                    ),
                  ),
      );
    });
  }
}
