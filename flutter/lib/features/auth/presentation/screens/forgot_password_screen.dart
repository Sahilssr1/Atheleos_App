import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/password_validator.dart';
import '../../../../core/widgets/password_requirements_view.dart';
import '../../../../core/widgets/atheleos_logo.dart';
import '../controllers/auth_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

enum ForgotPasswordStep {
  emailInput,
  otpVerification,
  newPassword,
  success,
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.emailInput;

  // Controllers
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // State flags
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _localError;
  bool _isProcessing = false;

  // Resend Timer
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp =>
      _otpControllers.map((c) => c.text.trim()).join();

  // ──────────────────────────────────────────────────
  // ACTION 1: Send Email OTP
  // ──────────────────────────────────────────────────
  Future<void> _handleSendEmailOtp() async {
    setState(() => _localError = null);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _localError = 'Please enter your email address');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _localError = 'Please enter a valid email address');
      return;
    }

    setState(() => _isProcessing = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .sendForgotPasswordOTP(email);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error == null) {
      setState(() {
        _currentStep = ForgotPasswordStep.otpVerification;
        _localError = null;
      });
      _startResendTimer();
      // Focus first OTP field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_otpFocusNodes.isNotEmpty && mounted) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } else {
      setState(() => _localError = error);
    }
  }

  // ──────────────────────────────────────────────────
  // ACTION 2: Resend Email OTP
  // ──────────────────────────────────────────────────
  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isProcessing) return;
    setState(() {
      _localError = null;
      _isProcessing = true;
    });

    final error = await ref
        .read(authControllerProvider.notifier)
        .sendForgotPasswordOTP(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error == null) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New verification code sent to ${_emailController.text.trim()}',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _localError = error);
    }
  }

  // ──────────────────────────────────────────────────
  // ACTION 3: Verify OTP
  // ──────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    setState(() => _localError = null);
    final otp = _enteredOtp;

    if (otp.length < 6) {
      setState(() => _localError = 'Please enter all 6 digits of the code');
      return;
    }

    setState(() => _isProcessing = true);
    final isVerified = await ref
        .read(authControllerProvider.notifier)
        .verifyForgotPasswordOTP(
          email: _emailController.text.trim(),
          code: otp,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (isVerified) {
      setState(() {
        _currentStep = ForgotPasswordStep.newPassword;
        _localError = null;
      });
    } else {
      setState(() => _localError =
          'Invalid or expired verification code. Please try again.');
    }
  }

  // ──────────────────────────────────────────────────
  // ACTION 4: Set New Password
  // ──────────────────────────────────────────────────
  Future<void> _handleResetPassword() async {
    setState(() => _localError = null);
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    final validationError = PasswordValidator.validate(newPass);
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _localError = 'Passwords do not match');
      return;
    }

    setState(() => _isProcessing = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .resetPasswordWithOtp(
          email: _emailController.text.trim(),
          code: _enteredOtp,
          newPassword: newPass,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error == null) {
      // 1. Tell Android Autofill / Google Password Manager to save/update this credential!
      try {
        TextInput.finishAutofillContext(shouldSave: true);
      } catch (_) {}

      // 2. Update local saved credentials in SharedPreferences
      try {
        await ref
            .read(authControllerProvider.notifier)
            .updateSavedPasswordForEmail(
              email: _emailController.text.trim(),
              newPassword: newPass,
            );
      } catch (_) {}

      setState(() {
        _currentStep = ForgotPasswordStep.success;
        _localError = null;
      });
    } else {
      setState(() => _localError = error);
    }
  }

  void _handleBackNavigation() {
    setState(() => _localError = null);
    switch (_currentStep) {
      case ForgotPasswordStep.emailInput:
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
        break;
      case ForgotPasswordStep.otpVerification:
        setState(() => _currentStep = ForgotPasswordStep.emailInput);
        break;
      case ForgotPasswordStep.newPassword:
        setState(() => _currentStep = ForgotPasswordStep.otpVerification);
        break;
      case ForgotPasswordStep.success:
        context.go('/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == ForgotPasswordStep.emailInput,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(AthIcons.arrowLeft, color: Colors.white, size: 20),
            onPressed: _handleBackNavigation,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AtheleosLogoIcon(size: 16),
              const SizedBox(width: 8),
              Text(
                'ATHELEOS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Ambient light circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.04),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_localError != null) ...[
                      _buildErrorBanner(_localError!),
                      const SizedBox(height: 16),
                    ],
                    _buildCurrentStepContent(),
                  ],
                ),
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: SpinKitSquareCircle(
                    color: AppTheme.primaryColor,
                    size: 44,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case ForgotPasswordStep.emailInput:
        return _buildEmailStep();
      case ForgotPasswordStep.otpVerification:
        return _buildOtpStep();
      case ForgotPasswordStep.newPassword:
        return _buildNewPasswordStep();
      case ForgotPasswordStep.success:
        return _buildSuccessStep();
    }
  }

  // ══════════════════════════════════════════════════
  // STEP 1: Email Input + Mobile Option
  // ══════════════════════════════════════════════════
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // Badge
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.35)),
            ),
            child: Text(
              'ACCOUNT RECOVERY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'FORGOT PASSWORD?',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered email address and we will send you a 6-digit verification code to reset your password.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),

        // Email field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
            prefixIcon: const Icon(AthIcons.envelope,
                color: AppTheme.primaryColor, size: 20),
            filled: true,
            fillColor: const Color(0xFF141414),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF282828)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
          onFieldSubmitted: (_) => _handleSendEmailOtp(),
        ),
        const SizedBox(height: 24),

        // Continue Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isProcessing ? null : _handleSendEmailOtp,
            child: Text(
              'SEND VERIFICATION CODE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 13,
              ),
            ),
          ),
        ),

        const SizedBox(height: 36),
        // Divider OR
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFF262626))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR SIGN IN DIRECTLY',
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFF262626))),
          ],
        ),
        const SizedBox(height: 28),

        // Path 2: Phone Login Option
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF242424)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(AthIcons.devicePhoneMobile,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login with Phone Number',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Instant OTP login without needing your password.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.6),
                        width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ref
                        .read(authControllerProvider.notifier)
                        .goToPhoneLogin();
                    context.go('/login');
                  },
                  child: Text(
                    'SIGN IN VIA PHONE NUMBER',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        Center(
          child: TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
            child: Text(
              'Back to Sign In',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════
  // STEP 2: 6-Digit Email OTP Entry
  // ══════════════════════════════════════════════════
  Widget _buildOtpStep() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.35)),
            ),
            child: Text(
              'STEP 2 OF 3',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'VERIFY EMAIL',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
                fontSize: 13, color: Colors.white70, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a 6-digit verification code to '),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '. Check your inbox and spam folders:'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 6-digit boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF282828)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.8),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    if (index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else {
                      _otpFocusNodes[index].unfocus();
                      _handleVerifyOtp();
                    }
                  } else {
                    if (index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // Verify button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isProcessing ? null : _handleVerifyOtp,
            child: Text(
              'VERIFY CODE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Resend code row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code? ",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
            ),
            if (_resendCountdown > 0)
              Text(
                'Resend in ${_resendCountdown}s',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            else
              GestureDetector(
                onTap: _handleResendOtp,
                child: Text(
                  'Resend Code',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() => _currentStep = ForgotPasswordStep.emailInput);
            },
            icon: const Icon(AthIcons.pencilSquare,
                size: 14, color: Colors.white60),
            label: Text(
              'Change email address',
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════
  // STEP 3: Set New Password
  // ══════════════════════════════════════════════════
  Widget _buildNewPasswordStep() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.35)),
              ),
              child: Text(
                'STEP 3 OF 3',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'SET NEW PASSWORD',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a strong password with at least 8 characters to secure your Atheleos profile.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Account Email (associates new password with username for Google Password Manager)
          TextFormField(
            controller: _emailController,
            readOnly: true,
            enabled: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Account Email',
              labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(AthIcons.user,
                  color: AppTheme.primaryColor, size: 20),
              suffixIcon: const Icon(AthIcons.checkCircleSolid,
                  color: AppTheme.primaryColor, size: 16),
              filled: true,
              fillColor: const Color(0xFF101010),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF222222)),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // New Password field
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
              prefixIcon: const Icon(AthIcons.lockClosed,
                  color: AppTheme.primaryColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? AthIcons.eye
                      : AthIcons.eyeSlash,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              filled: true,
              fillColor: const Color(0xFF141414),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF282828)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PasswordRequirementsView(password: _newPasswordController.text),
          const SizedBox(height: 18),

          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              labelStyle: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
              prefixIcon: const Icon(AthIcons.lockClosed,
                  color: AppTheme.primaryColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? AthIcons.eye
                      : AthIcons.eyeSlash,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              filled: true,
              fillColor: const Color(0xFF141414),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF282828)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
            onFieldSubmitted: (_) => _handleResetPassword(),
          ),
          const SizedBox(height: 28),

          // Submit Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _handleResetPassword,
              child: Text(
                'UPDATE PASSWORD',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // STEP 4: Success Screen
  // ══════════════════════════════════════════════════
  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              AthIcons.check,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'PASSWORD UPDATED!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your password has been successfully reset. You can now log in to your Atheleos account with your new credentials.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white70,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              context.go('/login');
            },
            child: Text(
              'SIGN IN NOW',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AthIcons.exclamationCircle,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
