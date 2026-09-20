import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/password_validator.dart';

class PasswordRequirementsView extends StatelessWidget {
  final String password;

  const PasswordRequirementsView({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final hasMinLength = PasswordValidator.hasMinLength(password);
    final hasUpper = PasswordValidator.hasUppercase(password);
    final hasLower = PasswordValidator.hasLowercase(password);
    final hasNum = PasswordValidator.hasNumber(password);
    final hasSpecial = PasswordValidator.hasSpecialChar(password);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASSWORD MUST CONTAIN:',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildRuleItem('8+ characters', hasMinLength),
              _buildRuleItem('One uppercase (A-Z)', hasUpper),
              _buildRuleItem('One lowercase (a-z)', hasLower),
              _buildRuleItem('One number (0-9)', hasNum),
              _buildRuleItem('One special character (!@#\$...)', hasSpecial),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String label, bool isSatisfied) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSatisfied ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 13,
          color: isSatisfied ? AppTheme.primaryColor : Colors.white24,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isSatisfied ? Colors.white : Colors.white38,
            fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
