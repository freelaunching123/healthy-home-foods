import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class ReviewsScreen extends StatefulWidget {
  final String type; // 'product' or 'fruit'
  final String id;
  const ReviewsScreen({super.key, required this.type, required this.id});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _api = ApiClient();
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final endpoint = widget.type == 'product' ? ApiConstants.productReviews(widget.id) : ApiConstants.fruitReviews(widget.id);
      final res = await _api.get(endpoint, queryParameters: {'page': 1, 'page_size': 50});
      
      setState(() {
        _reviews = res.data['items'] ?? [];
        _averageRating = (res.data['average_rating'] as num?)?.toDouble() ?? 0.0;
        _totalReviews = res.data['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews';
        _isLoading = false;
      });
    }
  }

  void _showAddReviewSheet() {
    int rating = 5;
    final textController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Write a Review', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) => IconButton(
                      icon: Icon(
                        index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                      onPressed: () => setSheetState(() => rating = index + 1),
                    )),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      setSheetState(() => isSubmitting = true);
                      try {
                        final endpoint = widget.type == 'product' ? ApiConstants.productReviews(widget.id) : ApiConstants.fruitReviews(widget.id);
                        await _api.post(endpoint, data: {
                          'rating': rating,
                          'review_text': textController.text.trim(),
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: AppTheme.primaryGreen));
                          _loadReviews();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: ${e.toString()}'), backgroundColor: AppTheme.error));
                        }
                      } finally {
                        setSheetState(() => isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Submit Review', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Reviews', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReviewSheet,
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: Text('Write Review', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), TextButton(onPressed: _loadReviews, child: const Text('Retry'))]))
              : CustomScrollView(
                  slivers: [
                    if (_totalReviews > 0)
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Text(_averageRating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  Row(
                                    children: List.generate(5, (index) => Icon(
                                      index < _averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 16, color: Colors.amber,
                                    )),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$_totalReviews reviews', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                                ],
                              ),
                              // You can add rating bars here for 5, 4, 3, 2, 1 stars
                            ],
                          ),
                        ),
                      ),
                      
                    if (_totalReviews == 0)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('No reviews yet', style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textSecondary)),
                              const SizedBox(height: 8),
                              Text('Be the first to review!', style: GoogleFonts.inter(color: AppTheme.textLight)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final review = _reviews[index];
                            return Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                        child: Text(review['customer_name']?.substring(0, 1).toUpperCase() ?? 'A', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(review['customer_name'] ?? 'Anonymous', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                            Row(
                                              children: [
                                                ...List.generate(5, (i) => Icon(
                                                  i < review['rating'] ? Icons.star_rounded : Icons.star_outline_rounded,
                                                  size: 14, color: Colors.amber,
                                                )),
                                                const SizedBox(width: 8),
                                                Text(
                                                  review['created_at'].toString().split('T').first,
                                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textLight),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (review['review_text'] != null && review['review_text'].isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(review['review_text'], style: GoogleFonts.inter(color: AppTheme.textPrimary, height: 1.5)),
                                  ],
                                ],
                              ),
                            );
                          },
                          childCount: _reviews.length,
                        ),
                      ),
                  ],
                ),
    );
  }
}
