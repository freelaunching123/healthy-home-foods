import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_rules.dart';

class PasswordValidationRulesWidget extends StatelessWidget {
  final String password;

  const PasswordValidationRulesWidget({super.key, required this.password});

  Widget _buildRuleRow(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isSatisfied ? AppTheme.success : Colors.grey.shade400,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSatisfied ? AppTheme.success : AppTheme.textSecondary,
              fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRuleRow('Minimum 8 characters (max 32)', PasswordRules.hasMinMaxChars(password)),
          _buildRuleRow('One uppercase letter', PasswordRules.hasUppercase(password)),
          _buildRuleRow('One lowercase letter', PasswordRules.hasLowercase(password)),
          _buildRuleRow('One number', PasswordRules.hasNumber(password)),
          _buildRuleRow('One special character', PasswordRules.hasSpecialChar(password)),
        ],
      ),
    );
  }
}
