import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryCalendarScreen extends StatefulWidget {
  final String subscriptionId;
  const DeliveryCalendarScreen({super.key, required this.subscriptionId});

  @override
  State<DeliveryCalendarScreen> createState() => _DeliveryCalendarScreenState();
}

class _DeliveryCalendarScreenState extends State<DeliveryCalendarScreen> {
  final _api = ApiClient();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _deliveriesMap = {};
  Map<String, dynamic>? _subDetail;
  Set<DateTime> _pausedDates = {};
  Map<DateTime, String> _deliveryScheduleMap = {};
  DateTime? _computedEndDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Subscription details
      try {
        final subRes = await _api.get('${ApiConstants.subscriptions}/${widget.subscriptionId}');
        _subDetail = subRes.data is Map<String, dynamic> ? subRes.data : null;
      } catch (e) {
        debugPrint('Error fetching subscription details: $e');
      }

      // 2. Fetch Deliveries list
      final delRes = await _api.get('${ApiConstants.subscriptions}/${widget.subscriptionId}/deliveries');
      final items = delRes.data['items'] as List<dynamic>? ?? [];

      final Map<DateTime, List<dynamic>> newMap = {};
      for (var item in items) {
        if (item['scheduled_date'] != null) {
          final date = DateTime.parse(item['scheduled_date']).toLocal();
          final normalizedDate = DateTime(date.year, date.month, date.day);
          if (newMap[normalizedDate] == null) newMap[normalizedDate] = [];
          newMap[normalizedDate]!.add(item);
        }
      }
      _deliveriesMap = newMap;

      // 3. Compute Schedule (Sunday Holidays & Paused Extensions)
      _computeSchedule();
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeSchedule() {
    if (_subDetail == null) return;

    final startDateStr = _subDetail!['start_date'] as String?;
    if (startDateStr == null) return;
    final startDateParsed = DateTime.parse(startDateStr).toLocal();
    final start = DateTime(startDateParsed.year, startDateParsed.month, startDateParsed.day);

    final totalDeliveries = (_subDetail!['total_deliveries'] as num?)?.toInt() ?? 6;
    final pauseHistory = _subDetail!['pause_history'] as List<dynamic>? ?? [];

    final Set<DateTime> paused = {};

    // Extract paused dates from pause_history
    for (var p in pauseHistory) {
      if (p['paused_at'] != null) {
        final pStart = DateTime.parse(p['paused_at']).toLocal();
        final pStartNorm = DateTime(pStart.year, pStart.month, pStart.day);
        DateTime pEndNorm;
        if (p['resumed_at'] != null) {
          final pEnd = DateTime.parse(p['resumed_at']).toLocal();
          pEndNorm = DateTime(pEnd.year, pEnd.month, pEnd.day);
        } else {
          final now = DateTime.now();
          pEndNorm = DateTime(now.year, now.month, now.day);
        }

        var curr = pStartNorm;
        while (!curr.isAfter(pEndNorm)) {
          paused.add(curr);
          curr = curr.add(const Duration(days: 1));
        }
      }
    }

    // Also check if current sub status is paused
    final status = (_subDetail!['status'] ?? '').toString().toLowerCase();
    if (status == 'paused' && _subDetail!['paused_at'] != null) {
      final pStart = DateTime.parse(_subDetail!['paused_at']).toLocal();
      final pStartNorm = DateTime(pStart.year, pStart.month, pStart.day);
      final now = DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      var curr = pStartNorm;
      while (!curr.isAfter(todayNorm)) {
        paused.add(curr);
        curr = curr.add(const Duration(days: 1));
      }
    }

    _pausedDates = paused;

    // Compute delivery schedule: start date to N delivery days
    final Map<DateTime, String> schedule = {};
    int scheduledCount = 0;
    var currentDay = start;

    int maxLoop = 365;
    while (scheduledCount < totalDeliveries && maxLoop > 0) {
      maxLoop--;
      final normalized = DateTime(currentDay.year, currentDay.month, currentDay.day);

      if (currentDay.weekday == DateTime.sunday) {
        // Sunday is Holiday - skipped from delivery count
      } else if (paused.contains(normalized)) {
        // Paused day - skipped from delivery count & extends schedule
      } else {
        // Valid working delivery day
        scheduledCount++;
        schedule[normalized] = 'Scheduled Day $scheduledCount';
      }

      if (scheduledCount < totalDeliveries) {
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    _deliveryScheduleMap = schedule;
    _computedEndDate = currentDay;
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _deliveriesMap[normalizedDay] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return AppTheme.delivered;
      case 'pending': return AppTheme.pending;
      case 'out_for_delivery': return AppTheme.outForDelivery;
      case 'failed': return AppTheme.error;
      case 'cancelled': return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }

  Widget _buildCalendarDayCell(BuildContext context, DateTime day, {bool isSelected = false, bool isToday = false}) {
    final normalized = DateTime(day.year, day.month, day.day);
    final isSunday = day.weekday == DateTime.sunday;
    final isPaused = _pausedDates.contains(normalized);
    final isDeliveryDay = _deliveryScheduleMap.containsKey(normalized);
    final dbEvents = _deliveriesMap[normalized] ?? [];

    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.textPrimary;
    String? badgeText;
    Color badgeColor = Colors.transparent;

    if (isSelected) {
      bgColor = AppTheme.primaryGreen;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppTheme.primaryGreen.withValues(alpha: 0.15);
    }

    if (isSunday) {
      badgeText = 'Holiday';
      badgeColor = Colors.orange.shade700;
    } else if (isPaused) {
      badgeText = 'Paused';
      badgeColor = Colors.amber.shade800;
    } else if (dbEvents.isNotEmpty) {
      final status = (dbEvents.first['status'] ?? '').toString();
      if (status == 'delivered') {
        badgeText = 'Delivered';
        badgeColor = AppTheme.delivered;
      } else if (status == 'out_for_delivery') {
        badgeText = 'Out';
        badgeColor = AppTheme.outForDelivery;
      } else {
        badgeText = 'Delivery';
        badgeColor = AppTheme.primaryGreen;
      }
    } else if (isDeliveryDay) {
      badgeText = 'Delivery';
      badgeColor = AppTheme.primaryGreen;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: isToday && !isSelected ? Border.all(color: AppTheme.primaryGreen) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isSunday ? Colors.orange.shade900 : textColor),
              fontSize: 13,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : badgeColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Delivery Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Subscription Summary Header Card
                  if (_subDetail != null) _buildSubscriptionSummaryCard(),

                  // Legend Bar
                  _buildLegendBar(),

                  // Calendar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                          _focusedDay = focusedDay;
                        });
                      },
                      eventLoader: _getEventsForDay,
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (ctx, day, focusedDay) => _buildCalendarDayCell(ctx, day),
                        selectedBuilder: (ctx, day, focusedDay) => _buildCalendarDayCell(ctx, day, isSelected: true),
                        todayBuilder: (ctx, day, focusedDay) => _buildCalendarDayCell(ctx, day, isToday: true),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Selected Date Details Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDay != null ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!) : 'Select a date',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        _buildSelectedDateDetail(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionSummaryCard() {
    final planName = _subDetail!['plan_name'] ?? _subDetail!['product_name'] ?? 'Meal Subscription';
    final total = _subDetail!['total_deliveries'] ?? 6;
    final completed = _subDetail!['completed_deliveries'] ?? 0;
    final startDateStr = _subDetail!['start_date'] as String?;
    String startDateFormatted = '—';
    if (startDateStr != null) {
      try {
        startDateFormatted = DateFormat('MMM dd, yyyy').format(DateTime.parse(startDateStr));
      } catch (_) {}
    }
    String endDateFormatted = '—';
    if (_computedEndDate != null) {
      endDateFormatted = DateFormat('MMM dd, yyyy').format(_computedEndDate!);
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen.withValues(alpha: 0.08), AppTheme.primaryGreen.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$planName ($total Deliveries)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completed / $total Done',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(startDateFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scheduled End Date', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(endDateFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Delivery', AppTheme.primaryGreen),
          _buildLegendItem('Sunday Holiday', Colors.orange.shade700),
          _buildLegendItem('Paused', Colors.amber.shade800),
          _buildLegendItem('Delivered', AppTheme.delivered),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSelectedDateDetail() {
    if (_selectedDay == null) {
      return const Text('Select a date on the calendar to view status.', style: TextStyle(color: AppTheme.textSecondary));
    }

    final normalized = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final isSunday = _selectedDay!.weekday == DateTime.sunday;
    final isPaused = _pausedDates.contains(normalized);
    final isDeliveryDay = _deliveryScheduleMap.containsKey(normalized);
    final dbEvents = _deliveriesMap[normalized] ?? [];

    if (isSunday) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.beach_access_rounded, color: Colors.orange.shade800, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sunday Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange.shade900)),
                  const SizedBox(height: 2),
                  const Text('Sunday is a weekly holiday. No delivery is scheduled today.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isPaused) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.pause_circle_rounded, color: Colors.amber.shade800, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscription Paused', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber.shade900)),
                  const SizedBox(height: 2),
                  const Text('Your subscription was paused on this day. The delivery day has been automatically extended.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (dbEvents.isNotEmpty) {
      final dayLabel = _deliveryScheduleMap[normalized] ?? '';
      final total = (_subDetail?['total_deliveries'] as num?)?.toInt() ?? 6;
      final planName = _subDetail?['plan_name'] ?? _subDetail?['product_name'] ?? 'Package Delivery';
      final session = (_subDetail?['delivery_session'] ?? 'Morning').toString();

      return Column(
        children: dbEvents.map((delivery) {
          final status = (delivery['status'] ?? 'pending').toString().toLowerCase();
          final color = _getStatusColor(status);
          final deliveredAt = delivery['delivered_at'] as String?;
          String deliveredTimeStr = '';
          if (deliveredAt != null) {
            try {
              deliveredTimeStr = DateFormat('hh:mm a').format(DateTime.parse(deliveredAt).toLocal());
            } catch (_) {}
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'delivered' ? Icons.check_circle_rounded :
                            status == 'out_for_delivery' ? Icons.directions_bike_rounded :
                            Icons.local_shipping_rounded,
                            color: color,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                          ),
                        ],
                      ),
                    ),
                    if (dayLabel.isNotEmpty)
                      Text(
                        dayLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryGreen),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  planName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      deliveredTimeStr.isNotEmpty ? 'Delivered at $deliveredTimeStr' : '$session Session Delivery',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (status == 'out_for_delivery') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/tracking/${delivery['id']}'),
                      icon: const Icon(Icons.location_on, size: 16),
                      label: const Text('Track Live Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    if (isDeliveryDay) {
      final label = _deliveryScheduleMap[normalized] ?? 'Scheduled Delivery';
      final planName = _subDetail?['plan_name'] ?? _subDetail?['product_name'] ?? 'Package Delivery';
      final session = (_subDetail?['delivery_session'] ?? 'Morning').toString();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, color: AppTheme.primaryGreen, size: 14),
                      SizedBox(width: 6),
                      Text('SCHEDULED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                    ],
                  ),
                ),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryGreen)),
              ],
            ),
            const SizedBox(height: 12),
            Text(planName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Scheduled for $session Session', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_busy_rounded, color: AppTheme.textSecondary, size: 24),
          SizedBox(width: 12),
          Text('No delivery scheduled for this day.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

