import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _recentlyViewedPackagesKey = 'recently_viewed_packages';
  static const String _recentlyViewedFruitsKey = 'recently_viewed_fruits';
  static const String _wishlistKey = 'wishlist_items';

  static Future<void> addRecentlyViewed(String type, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'package' ? _recentlyViewedPackagesKey : _recentlyViewedFruitsKey;
    final String? data = prefs.getString(key);
    List<dynamic> items = data != null ? jsonDecode(data) : [];
    
    // Remove if already exists to move to top
    items.removeWhere((e) => e['id'] == item['id']);
    items.insert(0, item);
    
    // Keep only last 10
    if (items.length > 10) items = items.sublist(0, 10);
    
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> getRecentlyViewed(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'package' ? _recentlyViewedPackagesKey : _recentlyViewedFruitsKey;
    final String? data = prefs.getString(key);
    if (data == null) return [];
    
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Wishlist
  static Future<void> toggleWishlist(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_wishlistKey);
    List<dynamic> items = data != null ? jsonDecode(data) : [];
    
    final index = items.indexWhere((e) => e['id'] == item['id']);
    if (index != -1) {
      items.removeAt(index);
    } else {
      items.add(item);
    }
    await prefs.setString(_wishlistKey, jsonEncode(items));
  }

  static Future<bool> isInWishlist(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_wishlistKey);
    if (data == null) return false;
    List<dynamic> items = jsonDecode(data);
    return items.any((e) => e['id'] == id);
  }

  static Future<List<Map<String, dynamic>>> getWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_wishlistKey);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
