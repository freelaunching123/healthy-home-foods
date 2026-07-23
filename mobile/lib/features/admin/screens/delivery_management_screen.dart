import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/file_saver.dart';
import '../widgets/admin_drawer.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'all';
  String _selectedPartnerId = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _partners = [];
  Map<String, dynamic> _analytics = {};

  bool _isLoading = true;
  bool _isLoadingAnalytics = true;
  bool _isActionInProgress = false;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_isActionInProgress) {
        _loadDeliveries();
        _loadAnalytics();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLoadingAnalytics = true;
    });

    try {
      await Future.wait([
        _loadDeliveries(),
        _loadAnalytics(),
        _loadPartners(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _loadDeliveries() async {
    try {
      final Map<String, dynamic> qParams = {
        'selected_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      if (_selectedStatus != 'all') {
        qParams['status'] = _selectedStatus;
      }
      if (_selectedPartnerId != 'all') {
        qParams['delivery_partner_id'] = _selectedPartnerId;
      }
      if (_searchQuery.isNotEmpty) {
        qParams['search'] = _searchQuery;
      }

      final res = await _api.get(ApiConstants.adminDeliveries, queryParameters: qParams);
      if (res.data is List) {
        setState(() {
          _deliveries = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
      rethrow;
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      final Map<String, dynamic> qParams = {
        'selected_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      final res = await _api.get(ApiConstants.adminDeliveriesAnalytics, queryParameters: qParams);
      if (res.data is Map) {
        setState(() {
          _analytics = res.data as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _loadPartners() async {
    try {
      final res = await _api.get('/delivery-partners');
      if (res.data is List) {
        setState(() {
          _partners = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
      rethrow;
    }
  }

  // Assignment removed as per requirements

  Future<void> _updateStatus(String deliveryId, String status, {String? reason}) async {
    setState(() => _isActionInProgress = true);
    try {
      await _api.put('${ApiConstants.adminDeliveries}/$deliveryId/status', data: {
        'status': status,
        'failure_reason': reason,
      });
      _showSuccessSnackBar('Delivery status updated successfully');
      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Failed to update status: $e');
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _exportData(String format) async {
    setState(() => _isActionInProgress = true);
    try {
      final Map<String, dynamic> qParams = {
        'format': format,
        'selected_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      if (_selectedStatus != 'all') {
        qParams['status'] = _selectedStatus;
      }
      if (_selectedPartnerId != 'all') {
        qParams['delivery_partner_id'] = _selectedPartnerId;
      }
      if (_searchQuery.isNotEmpty) {
        qParams['search'] = _searchQuery;
      }

      final res = await _api.dio.get<List<int>>(
        '${_api.dio.options.baseUrl}${ApiConstants.adminDeliveriesExport}',
        queryParameters: qParams,
        options: Options(responseType: ResponseType.bytes),
      );

      if (res.data != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final filename = 'deliveries_$dateStr.$format';
        await saveAndShareFile(res.data!, filename);
        _showSuccessSnackBar('Exported successfully: $filename');
      } else {
        throw Exception('Received empty data');
      }
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.success),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAllData();
    }
  }

  void _showDetails(Map<String, dynamic> delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeliveryDetailsSheet(
        deliveryId: delivery['id'],
        partners: _partners,
        onStatusUpdate: (status, reason) => _updateStatus(delivery['id'], status, reason: reason),
        onAssignPartner: (_) {}, // Dummy callback to prevent hot reload issues
      ),
    );
  }

  void _showPrintPreview() {
    showDialog(
      context: context,
      builder: (context) => _PrintPreviewDialog(
        date: _selectedDate,
        deliveries: _deliveries,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.pending;
      case 'assigned':
        return AppTheme.info;
      case 'picked_up':
        return Colors.teal;
      case 'out_for_delivery':
        return AppTheme.outForDelivery;
      case 'delivered':
        return AppTheme.delivered;
      case 'failed':
      case 'missed':
        return AppTheme.missed;
      case 'cancelled':
      case 'skipped':
        return Colors.grey;
      case 'carry_forward':
        return AppTheme.carryForward;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.scaffoldBg,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          color: AppTheme.textPrimary,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F0F0), height: 1),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [


                      // Analytics Top Cards
                      if (_isLoadingAnalytics)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(color: AppTheme.primaryGreen),
                        )
                      else
                        _buildAnalyticsPanel(isDesktop),

                      // Filters & Search Panel
                      _buildFiltersPanel(isDesktop),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                      ),
                    ),
                  )
                else if (_deliveries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else if (isDesktop)
                  SliverToBoxAdapter(child: _buildTableView())
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final d = _deliveries[i];
                          final displayStatus = d['status']?.toString() ?? 'pending';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order: ${d['subscription_id'].toString().substring(0, 8)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      _StatusBadge(
                                        label: _formatStatus(displayStatus),
                                        color: _getStatusColor(displayStatus),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Customer: ${d['customer_name'] ?? 'Unknown'} (${d['phone'] ?? ''})'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Address: ${d['delivery_address'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Time: ${d['delivery_time'] ?? 'Anytime'}'),
                                      Text(
                                        '₹${d['amount'] ?? 0.0}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(80, 36),
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          backgroundColor: AppTheme.primaryGreen,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _showDetails(d),
                                        child: const Text('Details', style: TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _deliveries.length,
                      ),
                    ),
                  ),
              ],
            ),
          if (_isActionInProgress)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPanel(bool isDesktop) {
    final metrics = [
      _MetricData(
        'Total Scheduled',
        '${_analytics['total_deliveries'] ?? 0}',
        Icons.local_shipping_outlined,
        AppTheme.primaryGreen,
      ),
      _MetricData(
        'Delivered',
        '${_analytics['delivered'] ?? 0}',
        Icons.check_circle_outline,
        AppTheme.primaryGreen,
      ),
      _MetricData(
        'Pending',
        '${(int.tryParse(_analytics['pending']?.toString() ?? '0') ?? 0) + (int.tryParse(_analytics['assigned']?.toString() ?? '0') ?? 0) + (int.tryParse(_analytics['out_for_delivery']?.toString() ?? '0') ?? 0)}',
        Icons.watch_later_outlined,
        AppTheme.warning,
      ),
      _MetricData(
        'Failed',
        '${_analytics['failed'] ?? 0}',
        Icons.error_outline,
        AppTheme.error,
      ),
    ];

    if (isDesktop) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: _MetricCard(data: metrics[0])),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(data: metrics[1])),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(data: metrics[2])),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(data: metrics[3])),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: metrics.map((m) => _MetricCard(data: m)).toList(),
        ),
      );
    }
  }

  Widget _buildFiltersPanel(bool isDesktop) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    final filters = [
      // Search Box
      Expanded(
        flex: isDesktop ? 2 : 1,
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() => _searchQuery = val);
            _loadDeliveries();
          },
          decoration: InputDecoration(
            hintText: 'Search order, customer, driver...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadDeliveries();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(width: 10),

      // Status Filter
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _selectedStatus,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Status',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'assigned', child: Text('Assigned', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'out_for_delivery', child: Text('Out for Delivery', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'delivered', child: Text('Delivered', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'failed', child: Text('Failed', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedStatus = val);
              _loadDeliveries();
            }
          },
        ),
      ),
      const SizedBox(width: 10),

      // Driver Filter
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _selectedPartnerId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Driver',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Drivers', overflow: TextOverflow.ellipsis)),
            ..._partners.map((p) => DropdownMenuItem(
                  value: p['id'].toString(),
                  child: Text(p['full_name'] ?? 'Driver', overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPartnerId = val);
              _loadDeliveries();
            }
          },
        ),
      ),
    ];

    final datePickerRow = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
            _loadAllData();
          },
        ),
        Flexible(
          child: InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
            _loadAllData();
          },
        ),
        const Spacer(),
        // Actions
        PopupMenuButton<String>(
          tooltip: 'Export / Print Options',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'csv') _exportData('csv');
            if (value == 'excel') _exportData('excel');
            if (value == 'print') _showPrintPreview();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(Icons.file_present, size: 16),
                  SizedBox(width: 8),
                  Text('Export CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.table_view_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Export Excel'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'print',
              child: Row(
                children: [
                  Icon(Icons.print_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Print Report'),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          datePickerRow,
          const SizedBox(height: 10),
          if (isDesktop)
            Row(children: filters)
          else
            Column(
              children: [
                Row(children: [filters[0]]), // Search box full width
                const SizedBox(height: 8),
                Row(
                  children: [
                    filters[2], // Status dropdown
                    const SizedBox(width: 8),
                    filters[4], // Driver dropdown
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _deliveries.length,
      itemBuilder: (context, i) {
        final d = _deliveries[i];
        final partnerId = d['delivery_partner_id']?.toString();
        final displayStatus = d['status']?.toString() ?? 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order: ${d['subscription_id'].toString().substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _StatusBadge(
                      label: _formatStatus(displayStatus),
                      color: _getStatusColor(displayStatus),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Customer: ${d['customer_name'] ?? 'Unknown'} (${d['phone'] ?? ''})'),
                const SizedBox(height: 4),
                Text(
                  'Address: ${d['delivery_address'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Time: ${d['delivery_time'] ?? 'Anytime'}'),
                    Text(
                      '₹${d['amount'] ?? 0.0}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showDetails(d),
                      child: const Text('Details', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.grey.shade200,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            dataRowMaxHeight: 68,
            columns: const [
              DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Scheduled', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _deliveries.map((d) {
              final partnerId = d['delivery_partner_id']?.toString();
              final displayStatus = d['status']?.toString() ?? 'pending';

              return DataRow(
                cells: [
                  DataCell(Text(d['subscription_id'].toString().substring(0, 8))),
                  DataCell(Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['customer_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(d['phone'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  )),
                  DataCell(Container(
                    width: 200,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      d['delivery_address'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                  DataCell(Text(d['delivery_time'] ?? 'Anytime')),
                  DataCell(Text('₹${d['amount'] ?? 0.0}')),
                  DataCell(_StatusBadge(
                    label: d['payment_status'] ?? 'Pending',
                    color: d['payment_status'] == 'Paid' ? AppTheme.success : AppTheme.warning,
                  )),
                  DataCell(_StatusBadge(
                    label: _formatStatus(displayStatus),
                    color: _getStatusColor(displayStatus),
                  )),
                  DataCell(ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showDetails(d),
                    child: const Text('Details', style: TextStyle(fontSize: 12)),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No scheduled deliveries found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try modifying filters or selecting another date',
            style: TextStyle(color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Metric Widgets ─────────────────────────────────────────────────────────────

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Badge Widget ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Details Bottom Sheet ────────────────────────────────────────────────────────

class _DeliveryDetailsSheet extends StatefulWidget {
  final String deliveryId;
  final List<Map<String, dynamic>> partners;
  final Function(String status, String? reason) onStatusUpdate;
  final Function(String partnerId) onAssignPartner;

  const _DeliveryDetailsSheet({
    required this.deliveryId,
    required this.partners,
    required this.onStatusUpdate,
    required this.onAssignPartner,
  });

  @override
  State<_DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<_DeliveryDetailsSheet> {
  final _api = ApiClient();
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('${ApiConstants.adminDeliveries}/${widget.deliveryId}');
      if (res.data is Map) {
        setState(() {
          _detail = res.data as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? isoStr) {
    if (isoStr == null) return '';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _detail == null
              ? const Center(child: Text('Failed to load details'))
              : Column(
                  children: [
                    // Pull Handle & Header
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery Details (${_detail!['id'].toString().substring(0, 8)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Content
                    Expanded(
                      child: isWide ? _buildWideLayout() : _buildScrollableLayout(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Info Panels & Actions)
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoPanels(),
                const SizedBox(height: 16),
                _buildOrderedProducts(),
                const SizedBox(height: 16),
                _buildActionControllers(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Right Column (Timeline & Logs)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimelineStepper(),
                const SizedBox(height: 20),
                _buildAssignmentLogs(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoPanels(),
          const SizedBox(height: 16),
          _buildOrderedProducts(),
          const SizedBox(height: 16),
          _buildActionControllers(),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          _buildTimelineStepper(),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          _buildAssignmentLogs(),
        ],
      ),
    );
  }

  Widget _buildInfoPanels() {
    final cust = _detail!['customer'] ?? {};
    final driver = _detail!['delivery_partner'] ?? {};
    final addr = _detail!['address'] ?? {};

    return Column(
      children: [
        // Customer Profile
        _buildPanelCard(
          'Customer Details',
          Icons.person_outline,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cust['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Mobile: ${cust['phone'] ?? ''}'),
              Text('Email: ${cust['email'] ?? ''}'),
              Text('Customer Code: ${cust['customer_code'] ?? ''}'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Driver Specs
        _buildPanelCard(
          'Delivery Partner Details',
          Icons.motorcycle_outlined,
          driver['full_name'] != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Mobile: ${driver['phone'] ?? ''}'),
                    Text('Employee Code: ${driver['employee_code'] ?? ''}'),
                    Text('Vehicle: ${driver['vehicle_type'] ?? ''} (${driver['vehicle_number'] ?? ''})'),
                  ],
                )
              : const Text('Unassigned / No driver assigned to this delivery day.'),
        ),
        const SizedBox(height: 12),

        // Address landmarks
        _buildPanelCard(
          'Delivery Address',
          Icons.pin_drop_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${addr['address_line1'] ?? ''}${addr['address_line2'] != null ? ', ${addr['address_line2']}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${addr['city'] ?? ''}, ${addr['state'] ?? ''} - ${addr['pincode'] ?? ''}'),
              if (addr['landmark'] != null && addr['landmark'].toString().isNotEmpty)
                Text('Landmark: ${addr['landmark']}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelCard(String title, IconData icon, Widget content) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildOrderedProducts() {
    final prods = (_detail!['products'] as List? ?? []);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen, size: 18),
                SizedBox(width: 8),
                Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prods.length,
              itemBuilder: (context, i) {
                final p = prods[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${p['product_name'] ?? 'Product'}  x  ${p['quantity'] ?? 1}'),
                      Text('₹${(p['price_per_delivery'] ?? 0.0) * (p['quantity'] ?? 1)}'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionControllers() {
    final currentStatus = _detail!['status']?.toString() ?? 'pending';
    final currentPartnerId = _detail!['delivery_partner']?['id']?.toString();

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentStatus,
                    decoration: InputDecoration(
                      labelText: 'Update Delivery Status',
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                      DropdownMenuItem(value: 'picked_up', child: Text('Picked Up')),
                      DropdownMenuItem(value: 'out_for_delivery', child: Text('Out for Delivery')),
                      DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null && val != currentStatus) {
                        if (val == 'failed') {
                          _promptFailureReason(val);
                        } else {
                          widget.onStatusUpdate(val, null);
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _promptFailureReason(String status) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Failure Reason'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Enter reason (e.g. Customer unavailable)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close details sheet
              widget.onStatusUpdate(status, reasonController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStepper() {
    final timeline = (_detail!['timeline'] as List? ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ...timeline.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final completed = step['completed'] as bool? ?? false;
          final isLast = i == timeline.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed ? AppTheme.success : Colors.grey.shade300,
                    ),
                    child: completed
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 36,
                      color: completed ? AppTheme.success : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatStatus(step['stage'] ?? ''),
                      style: TextStyle(
                        fontWeight: completed ? FontWeight.bold : FontWeight.normal,
                        color: completed ? AppTheme.textPrimary : AppTheme.textLight,
                      ),
                    ),
                    if (step['timestamp'] != null)
                      Text(
                        _formatDateTime(step['timestamp']),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildAssignmentLogs() {
    final logs = (_detail!['assignment_history'] as List? ?? []);
    if (logs.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assignment History Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final log = logs[i];
            final prev = log['previous_partner_name'] ?? 'Unassigned';
            final next = log['new_partner_name'] ?? 'Unassigned';
            final changer = log['changed_by_name'] ?? 'Admin';
            final time = _formatDateTime(log['changed_at']);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
                elevation: 0,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reassigned: $prev → $next', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('By: $changer', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Print Dialog ──────────────────────────────────────────────────────────────

class _PrintPreviewDialog extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> deliveries;

  const _PrintPreviewDialog({required this.date, required this.deliveries});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Text('Physical Report Print Layout - $dateStr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              printPage();
            },
            tooltip: 'Trigger Print API',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Healthy Home Foods - Delivery Report',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Scheduled Date: $dateStr', style: const TextStyle(fontSize: 14)),
                    Text('Printed at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(3),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    ],
                  ),
                  ...deliveries.map((d) {
                    final statusVal = d['status']?.toString() ?? 'pending';
                    final partnerVal = d['delivery_partner_name'] ?? 'Unassigned';

                    return TableRow(
                      children: [
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(d['subscription_id'].toString().substring(0, 8), style: const TextStyle(fontSize: 11)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text('${d['customer_name']}\n${d['phone']}', style: const TextStyle(fontSize: 11)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(d['delivery_address'] ?? '', style: const TextStyle(fontSize: 11)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(partnerVal, style: const TextStyle(fontSize: 11)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(statusVal, style: const TextStyle(fontSize: 11)))),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
