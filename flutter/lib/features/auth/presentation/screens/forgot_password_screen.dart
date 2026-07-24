import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final error = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailController.text.trim());

    if (mounted) {
      if (error == null) {
        setState(() => _emailSent = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.withOpacity(0.85),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _emailSent
              ? _buildSuccessState(context)
              : _buildRequestState(context, authState),
        ),
      ),
    );
  }

  Widget _buildRequestState(BuildContext context, AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── Title ──────────────────────────────────────────────
          Text(
            'ACCOUNT RECOVERY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a recovery method to regain access to your Atheleos account.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white60,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),

          // ── PATH 1: Email Reset ─────────────────────────────────
          _buildSectionHeader('PATH 1', 'Reset via Alternate Email'),
          const SizedBox(height: 16),

          // Email Input
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Alternate Email Address',
              prefixIcon: Icon(Icons.email_outlined,
                  color: AppTheme.primaryColor, size: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleResetPassword(),
          ),
          const SizedBox(height: 20),

          // Error message
          if (authState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Send reset button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: authState.isLoading ? null : _handleResetPassword,
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'SEND RESET LINK',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
            ),
          ),

          // ── Divider ────────────────────────────────────────────
          const SizedBox(height: 40),
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 32),

          // ── PATH 2: Phone OTP ───────────────────────────────────
          _buildSectionHeader('PATH 2', 'Sign in with Mobile OTP'),
          const SizedBox(height: 12),
          Text(
            'If you can\'t access your email, sign in directly with your registered mobile number and receive a one-time code.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.phone_android,
                  color: AppTheme.primaryColor, size: 18),
              label: Text(
                'SIGN IN WITH MOBILE OTP',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
              onPressed: () {
                // Pop the standalone route and navigate to the phone login step
                context.pop();
                ref
                    .read(authControllerProvider.notifier)
                    .goToPhoneLogin();
              },
            ),
          ),

          const SizedBox(height: 40),

          // ── Back to Sign In ─────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Sign In',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 28),
        Text(
          'Reset Link Sent!',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We have sent a password reset link to:\n${_emailController.text}\n\nPlease check your inbox and spam folders.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white60,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.pop(),
            child: Text(
              'BACK TO SIGN IN',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String badge, String title) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.4)),
          ),
          child: Text(
            badge,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
