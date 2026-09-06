import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error_handler.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final _api = ApiClient();
  Timer? _refreshTimer;

  String _selectedPreset = '30d';
  String? _startDate;
  String? _endDate;
  DateTimeRange? _customDateRange;

  String _selectedCategory = 'all'; // 'all', 'packages', 'groceries'

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  @override
  void initState() {
    super.initState();
    _applyPreset('30d', autoFetch: false);
    _loadPurchases();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadPurchases(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _applyPreset(String preset, {bool autoFetch = true}) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (preset == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (preset == 'yesterday') {
      final y = now.subtract(const Duration(days: 1));
      start = DateTime(y.year, y.month, y.day);
      end = DateTime(y.year, y.month, y.day, 23, 59, 59);
    } else if (preset == '7d') {
      start = now.subtract(const Duration(days: 6));
    } else if (preset == '30d') {
      start = now.subtract(const Duration(days: 29));
    } else if (preset == 'month') {
      start = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _selectedPreset = preset;
      if (preset != 'custom') {
        _startDate = start != null ? DateFormat('yyyy-MM-dd').format(start) : null;
        _endDate = end != null ? DateFormat('yyyy-MM-dd').format(end) : null;
        _customDateRange = null;
      }
    });

    if (autoFetch) {
      _loadPurchases();
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
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

    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _customDateRange = picked;
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadPurchases();
    }
  }

  Future<void> _loadPurchases({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final queryParams = <String, dynamic>{
        'category': _selectedCategory,
      };
      if (_startDate != null) queryParams['start_date'] = _startDate;
      if (_endDate != null) queryParams['end_date'] = _endDate;

      final res = await _api.get(
        ApiConstants.reportsPurchases,
        queryParameters: queryParams,
      );

      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!silent || _data == null) {
          setState(() {
            _errorMessage = ApiErrorHandler.getMessage(e);
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _exportStatement({required bool isPdf}) async {
    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    final endpoint = isPdf
        ? ApiConstants.reportsPurchasesExportPdf
        : ApiConstants.reportsPurchasesExportExcel;
    final extension = isPdf ? 'pdf' : 'xlsx';
    final filename = 'HealthyHomeFoods_Purchase_Statement_${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      final savePath = '${dir.path}/$filename';

      final queryParams = <String, dynamic>{
        'category': _selectedCategory,
      };
      if (_startDate != null) queryParams['start_date'] = _startDate;
      if (_endDate != null) queryParams['end_date'] = _endDate;

      await _api.dio.download(
        endpoint,
        savePath,
        queryParameters: queryParams,
      );

      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
        _showExportSuccessModal(savePath, filename, isPdf);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export statement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExportSuccessModal(String filePath, String filename, bool isPdf) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                  color: AppTheme.primaryGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Statement Exported Successfully!',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                filename,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Share.shareXFiles([XFile(filePath)], text: 'Healthy Home Foods Purchase Statement');
                      },
                      icon: const Icon(Icons.share_outlined, size: 20, color: AppTheme.textPrimary),
                      label: Text('Share', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await OpenFile.open(filePath);
                        if (result.type != ResultType.done && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open file: ${result.message}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Colors.white),
                      label: Text('Open File', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateRangeLabel() {
    if (_selectedPreset == 'custom' && _customDateRange != null) {
      return '${DateFormat('d MMM yyyy').format(_customDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_customDateRange!.end)}';
    }
    if (_startDate != null && _endDate != null) {
      try {
        final s = DateTime.parse(_startDate!);
        final e = DateTime.parse(_endDate!);
        return '${DateFormat('d MMM yyyy').format(s)} - ${DateFormat('d MMM yyyy').format(e)}';
      } catch (_) {}
    }
    return 'All Time';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final totalCount = summary?['total_count'] ?? 0;
    final grandTotal = (summary?['grand_total'] as num?)?.toDouble() ?? 0.0;
    final pkgAmt = (summary?['total_packages_amount'] as num?)?.toDouble() ?? 0.0;
    final frtAmt = (summary?['total_groceries_amount'] as num?)?.toDouble() ?? 0.0;
    final pkgCount = summary?['packages_count'] ?? 0;
    final frtCount = summary?['groceries_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Purchase History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Filter Controls Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('Today', 'today'),
                      const SizedBox(width: 8),
                      _buildPresetChip('Yesterday', 'yesterday'),
                      const SizedBox(width: 8),
                      _buildPresetChip('Last 7 Days', '7d'),
                      const SizedBox(width: 8),
                      _buildPresetChip('Last 30 Days', '30d'),
                      const SizedBox(width: 8),
                      _buildPresetChip('This Month', 'month'),
                      const SizedBox(width: 8),
                      _buildPresetChip('Custom', 'custom', isCustom: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Active Date Range banner + Category filter
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectCustomDateRange,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8E4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getDateRangeLabel(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Category Dropdown Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8E4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          icon: const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.primaryGreen),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Types')),
                            DropdownMenuItem(value: 'packages', child: Text('Packages')),
                            DropdownMenuItem(value: 'groceries', child: Text('Groceries')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                              _loadPurchases();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEFEFEF)),

          // Main Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _errorMessage != null
                    ? _buildErrorView()
                    : RefreshIndicator(
                        onRefresh: _loadPurchases,
                        color: AppTheme.primaryGreen,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary Breakdown Card
                              _buildSummaryCard(
                                totalCount: totalCount,
                                grandTotal: grandTotal,
                                pkgAmt: pkgAmt,
                                frtAmt: frtAmt,
                                pkgCount: pkgCount,
                                frtCount: frtCount,
                              ),
                              const SizedBox(height: 20),

                              // Export Action Buttons
                              Text(
                                'Export Statements',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildExportButtons(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String key, {bool isCustom = false}) {
    final isSelected = _selectedPreset == key;
    return InkWell(
      onTap: () {
        if (isCustom) {
          _selectCustomDateRange();
        } else {
          _applyPreset(key);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required int totalCount,
    required double grandTotal,
    required double pkgAmt,
    required double frtAmt,
    required int pkgCount,
    required int frtCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Healthy Home Foods Statement',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '$totalCount Orders',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Grand Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL COLLECTED',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${grandTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getDateRangeLabel(),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),
                // Breakdown Sub-Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.primaryGreen),
                                const SizedBox(width: 4),
                                Text('Packages ($pkgCount)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('₹${pkgAmt.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text('Groceries ($frtCount)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('₹${frtAmt.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        // Export PDF
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isExportingPdf || _isExportingExcel) ? null : () => _exportStatement(isPdf: true),
            icon: _isExportingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(
              _isExportingPdf ? 'Exporting PDF...' : 'Export PDF',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Export Excel
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isExportingPdf || _isExportingExcel) ? null : () => _exportStatement(isPdf: false),
            icon: _isExportingExcel
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_chart_rounded, size: 18),
            label: Text(
              _isExportingExcel ? 'Exporting Excel...' : 'Export Excel',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load purchase records',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loadPurchases,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
