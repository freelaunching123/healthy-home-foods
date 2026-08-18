import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const String facebookUrl = 'https://www.facebook.com/share/1PcuRhGy6M/';
  static const String instagramUrl =
      'https://www.instagram.com/healthy_home_foods_india?igsh=MXBzbGxkamNjMmR4cQ==';
  static const String phoneNumber = '+91 75981 66088';
  static const String emailAddress = 'healthyhomesmdu@gmail.com';
  static const String locationAddress = 'Madurai, Tamil Nadu, India';

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $urlString')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate theme matching reference image
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card / Logo banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGreen, width: 2),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppTheme.primaryGreen,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Healthy Home Foods',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Eat Healthy, Stay Healthy',
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content List Container matching reference image exactly
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  // 1. Phone
                  _buildListTile(
                    icon: Icons.phone_outlined,
                    iconColor: Colors.white70,
                    title: phoneNumber,
                    titleColor: Colors.white,
                    onTap: () => _openUrl(context, 'tel:+917598166088'),
                  ),
                  _buildDivider(),

                  // 2. Shop Time (Open now changed to Shop Time as requested)
                  _buildListTile(
                    icon: Icons.access_time_outlined,
                    iconColor: Colors.white70,
                    title: 'Shop Time',
                    titleColor: const Color(0xFF4ADE80), // Green
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '6:00 am –\n8:00 pm',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                      ],
                    ),
                  ),
                  _buildDivider(),

                  // 3. Restaurant Category
                  _buildListTile(
                    icon: Icons.category_outlined,
                    iconColor: Colors.white70,
                    title: 'Restaurant',
                    titleColor: Colors.white,
                  ),
                  _buildDivider(),

                  // 4. Tagline
                  _buildListTile(
                    icon: Icons.storefront_outlined,
                    iconColor: Colors.white70,
                    title: 'EAT HEALTHY STAY HEALTHY',
                    titleColor: Colors.white,
                  ),
                  _buildDivider(),

                  // 5. Location
                  _buildListTile(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.white70,
                    title: locationAddress,
                    titleColor: const Color(0xFF60A5FA), // Accent Blue
                    onTap: () => _openUrl(
                      context,
                      'https://www.google.com/maps/search/?api=1&query=Madurai,+Tamil+Nadu,+India',
                    ),
                  ),
                  _buildDivider(),

                  // 6. Email
                  _buildListTile(
                    icon: Icons.mail_outline,
                    iconColor: Colors.white70,
                    title: emailAddress,
                    titleColor: const Color(0xFF60A5FA), // Accent Blue
                    onTap: () => _openUrl(context, 'mailto:$emailAddress'),
                  ),
                  _buildDivider(),

                  // Note: Item 7 (Red marked scribble in user screenshot) is excluded per instruction!

                  // 8. Facebook Link
                  _buildListTile(
                    customIcon: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'f',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    title: 'healthyhome-madurai',
                    titleColor: const Color(0xFF4ADE80), // Green text
                    subtitle: 'Facebook • 7,872 Likes',
                    onTap: () => _openUrl(context, facebookUrl),
                  ),
                  _buildDivider(),

                  // 9. Instagram Link
                  _buildListTile(
                    customIcon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF833AB4),
                            Color(0xFFFD1D1D),
                            Color(0xFFF77737),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    title: '@healthy_home_foods_india',
                    titleColor: const Color(0xFF4ADE80), // Green text
                    subtitle: 'Instagram • 16,459 Followers',
                    onTap: () => _openUrl(context, instagramUrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    IconData? icon,
    Widget? customIcon,
    Color iconColor = Colors.white70,
    required String title,
    required Color titleColor,
    String? subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: customIcon ?? Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.06),
      indent: 62,
    );
  }
}
