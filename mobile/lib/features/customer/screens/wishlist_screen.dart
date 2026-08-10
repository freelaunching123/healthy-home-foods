import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _wishlist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final items = await LocalStorageService.getWishlist();
    setState(() {
      _wishlist = items;
      _isLoading = false;
    });
  }

  Future<void> _removeFromWishlist(Map<String, dynamic> item) async {
    await LocalStorageService.toggleWishlist(item);
    _loadWishlist();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Removed from wishlist'),
      duration: Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('My Wishlist', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _wishlist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Your wishlist is empty', style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wishlist.length,
                  itemBuilder: (context, index) {
                    final item = _wishlist[index];
                    final isFruit = item.containsKey('price_per_kg');
                    
                    final baseUrl = _api.dio.options.baseUrl.replaceAll('/api/v1', '');
                    final imageUrl = item['image_url'] != null ? '$baseUrl${item['image_url']}' : null;
                    final price = isFruit ? item['price_per_kg'] : item['package_price'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: InkWell(
                        onTap: () {
                          if (isFruit) {
                            context.push('/fruits/${item['id']}');
                          } else {
                            context.push('/product/${item['id']}');
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.eco, color: AppTheme.primaryGreen)),
                                    )
                                  : Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.eco, color: AppTheme.primaryGreen)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(isFruit ? 'GROCERY' : 'PACKAGE', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(item['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('₹${price.toString()}', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                              onPressed: () => _removeFromWishlist(item),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
