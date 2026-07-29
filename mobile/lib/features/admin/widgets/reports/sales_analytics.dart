import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'empty_state.dart';

class SalesAnalytics extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const SalesAnalytics({super.key, this.startDate, this.endDate});

  @override
  State<SalesAnalytics> createState() => _SalesAnalyticsState();
}

class _SalesAnalyticsState extends State<SalesAnalytics> {
  final _api = ApiClient();
  bool _isLoading = true;
  List<dynamic> _dailySales = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant SalesAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/reports/sales', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _dailySales = res.data['daily_sales'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching sales: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_dailySales.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        message: 'No sales available for the selected period.',
      );
    }

    double maxY = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < _dailySales.length; i++) {
      final revenue = (_dailySales[i]['revenue'] as num).toDouble();
      if (revenue > maxY) maxY = revenue;
      spots.add(FlSpot(i.toDouble(), revenue));
    }
    
    // Add 20% padding to maxY for chart
    maxY = maxY > 0 ? maxY * 1.2 : 100;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          if (value == maxY) return const SizedBox.shrink();
                          return Text('₹${_compactFormat(value)}', style: const TextStyle(color: Colors.grey, fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (_dailySales.length / 4).ceilToDouble().clamp(1.0, double.infinity),
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _dailySales.length) {
                            try {
                              final date = DateTime.parse(_dailySales[value.toInt()]['date']);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('MMM dd').format(date), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              );
                            } catch (_) {}
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (_dailySales.length - 1).toDouble().clamp(0, double.infinity),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryGreen,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactFormat(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
