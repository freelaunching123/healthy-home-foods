import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  static const String facebookUrl = 'https://www.facebook.com/share/1PcuRhGy6M/';
  static const String instagramUrl =
      'https://www.instagram.com/healthy_home_foods_india?igsh=MXBzbGxkamNjMmR4cQ==';
  static const String phoneNumber = '+91 75981 66088';
  static const String emailAddress = 'healthyhomesmdu@gmail.com';
  static const String locationAddress = 'Madurai, Tamil Nadu, India';

  bool _isTimingExpanded = false;

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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: AppTheme.textPrimary,
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
            // Top Banner Card with Official Logo Image
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Column(
                      children: const [
                        Icon(Icons.storefront_rounded, size: 60, color: AppTheme.primaryGreen),
                        SizedBox(height: 8),
                        Text(
                          'Healthy Home Foods',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sunday Holiday Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.event_busy_outlined, color: AppTheme.error, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Every Sunday is Holiday',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content List Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. Phone
                  _buildListTile(
                    icon: Icons.phone_outlined,
                    iconColor: AppTheme.primaryGreen,
                    title: phoneNumber,
                    titleColor: AppTheme.textPrimary,
                    onTap: () => _openUrl(context, 'tel:+917598166088'),
                  ),
                  _buildDivider(),

                  // 2. Expandable Shop Time
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isTimingExpanded = !_isTimingExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 32,
                                child: Icon(Icons.access_time_outlined, color: AppTheme.primaryGreen, size: 24),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Shop Time',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Text(
                                '6:00 am – 8:00 pm',
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isTimingExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                          if (_isTimingExpanded) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.scaffoldBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _buildDayRow('Monday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Tuesday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Wednesday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Thursday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Friday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Saturday', '6:00 am - 8:00 pm'),
                                  _buildDayRow('Sunday', 'Holiday', isHoliday: true),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildDivider(),



                  // 4. Location
                  _buildListTile(
                    icon: Icons.location_on_outlined,
                    iconColor: AppTheme.primaryGreen,
                    title: locationAddress,
                    titleColor: AppTheme.textPrimary,
                    onTap: () => _openUrl(
                      context,
                      'https://www.google.com/maps/search/?api=1&query=Madurai,+Tamil+Nadu,+India',
                    ),
                  ),
                  _buildDivider(),

                  // 5. Email
                  _buildListTile(
                    icon: Icons.mail_outline,
                    iconColor: AppTheme.primaryGreen,
                    title: emailAddress,
                    titleColor: AppTheme.textPrimary,
                    onTap: () => _openUrl(context, 'mailto:$emailAddress'),
                  ),
                  _buildDivider(),

                  // 6. Facebook Link
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
                    titleColor: AppTheme.primaryGreen,
                    onTap: () => _openUrl(context, facebookUrl),
                  ),
                  _buildDivider(),

                  // 7. Instagram Link
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
                    titleColor: AppTheme.primaryGreen,
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

  Widget _buildDayRow(String day, String timing, {bool isHoliday = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            timing,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHoliday ? FontWeight.bold : FontWeight.w600,
              color: isHoliday ? AppTheme.error : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    IconData? icon,
    Widget? customIcon,
    Color iconColor = AppTheme.primaryGreen,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 62,
    );
  }
}
