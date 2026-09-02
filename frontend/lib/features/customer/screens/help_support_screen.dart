import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 16),
            _buildFaqSection(),
            
            const SizedBox(height: 32),
            const Text(
              'Policies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              title: 'Terms and Conditions',
              content: '1. All orders placed are final.\n'
                       '2. Subscriptions start from the next day of order confirmation.\n'
                       '3. Healthy Home Foods is not responsible for missed deliveries if the customer is unavailable at the provided address.\n'
                       '4. We reserve the right to modify subscription contents based on seasonal availability.',
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              title: 'Privacy Policy',
              content: '1. We collect your name, phone number, and address strictly for delivery purposes.\n'
                       '2. Your payment information is securely processed by our payment gateway partners.\n'
                       '3. We do not sell or share your personal data with third-party advertisers.\n'
                       '4. Your location data is only used to assign the nearest delivery partner.',
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              title: 'Refund & Cancellation Policy',
              content: 'Healthy Home Foods maintains a strict No Refund and No Cancellation policy. '
                       'Once a grocery order or subscription package is purchased and paid for, it cannot be cancelled or refunded. '
                       'Please review your cart carefully before completing your payment.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    final faqs = [
      {
        'q': 'How does the Subscription Package work?',
        'a': 'When you subscribe to a package, you receive daily meals delivered directly to your address. Deliveries automatically start from the next day.'
      },
      {
        'q': 'Can I choose my delivery session?',
        'a': 'Yes! During checkout, you can select whether you want your delivery in the Morning, Afternoon, or Evening session.'
      },
      {
        'q': 'Do you deliver on Sundays?',
        'a': 'No, every Sunday is a holiday. We do not schedule deliveries on Sundays.'
      },
      {
        'q': 'How do Grocery deliveries work?',
        'a': 'Grocery orders are scheduled for next-day delivery. If you order today, your fresh groceries will arrive tomorrow in your selected session.'
      },
      {
        'q': 'What happens if I miss a delivery?',
        'a': 'If our delivery boy attempts to deliver but you are unavailable, the delivery will be marked as "Missed". Don\'t worry! Your missed delivery will automatically be carried forward and added as an extra day at the end of your subscription schedule.'
      },
      {
        'q': 'How can I track my delivery?',
        'a': 'You can view the status of your daily deliveries in the "Deliveries" tab at the bottom of your screen.'
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: faqs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                faqs[index]['q']!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: [
                Text(
                  faqs[index]['a']!,
                  style: const TextStyle(color: AppTheme.textLight, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicySection({required String title, required String content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(color: AppTheme.textLight, height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
