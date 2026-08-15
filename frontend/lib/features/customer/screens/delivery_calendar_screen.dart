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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('${ApiConstants.subscriptions}/${widget.subscriptionId}/deliveries');
      final items = res.data['items'] as List<dynamic>? ?? [];
      
      final Map<DateTime, List<dynamic>> newMap = {};
      for (var item in items) {
        if (item['scheduled_date'] != null) {
          final date = DateTime.parse(item['scheduled_date']).toLocal();
          final normalizedDate = DateTime(date.year, date.month, date.day);
          if (newMap[normalizedDate] == null) newMap[normalizedDate] = [];
          newMap[normalizedDate]!.add(item);
        }
      }
      setState(() => _deliveriesMap = newMap);
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: _getEventsForDay,
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
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
                          _selectedDay != null ? DateFormat('EEEE, MMMM d').format(_selectedDay!) : 'Select a date',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildDeliveriesList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDeliveriesList() {
    final deliveries = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    
    if (deliveries.isEmpty) {
      return const Center(
        child: Text('No deliveries scheduled for this day.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        final status = delivery['status'] ?? 'pending';
        final color = _getStatusColor(status);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(
                status == 'delivered' ? Icons.check : 
                status == 'out_for_delivery' ? Icons.directions_bike :
                Icons.local_shipping,
                color: color,
              ),
            ),
            title: Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
            subtitle: Text('Delivery ID: ${delivery['id'].toString().substring(0, 8)}...'),
            trailing: status == 'out_for_delivery'
                ? ElevatedButton(
                    onPressed: () => context.push('/tracking/${delivery['id']}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Track'),
                  )
                : null,
          ),
        );
      },
    );
  }
}
