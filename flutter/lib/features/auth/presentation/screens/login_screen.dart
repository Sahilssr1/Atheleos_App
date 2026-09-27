import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sport_selector_field.dart';
import '../../../../core/utils/password_validator.dart';
import '../../../../core/widgets/password_requirements_view.dart';
import '../../../../core/widgets/atheleos_logo.dart';
import '../../data/models/user_model.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Start PageView on the current auth step's page index so that
    // after sign-out (which sets step = login, index 1) we don't
    // get stuck on the splash page (index 0).
    final initialPage = ref.read(authControllerProvider).currentStep.index;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncPage(AuthStep step) {
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? _pageController.initialPage;
      final targetPage = step.index;

      if ((targetPage - currentPage).abs() > 1) {
        _pageController.jumpToPage(targetPage);
      } else {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    // Listen for step changes in the controller to animate the pageview smoothly
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.currentStep != next.currentStep) {
        _syncPage(next.currentStep);
      }
    });

    final step = authState.currentStep;
    final isOnboarding = step == AuthStep.createAccountCredentials ||
        step == AuthStep.phoneInput ||
        step == AuthStep.otpInput ||
        step == AuthStep.roleSelection ||
        step == AuthStep.location ||
        step == AuthStep.roleDetails;

    return PopScope(
      canPop: !isOnboarding,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          await ref.read(authControllerProvider.notifier).exitOnboarding();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background elegant elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.03),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  if (authState.currentStep != AuthStep.splash && authState.currentStep != AuthStep.complete)
                    _buildHeader(context, authState),

                  // Main steps PageView (disabled manual scroll to control flow sequentially)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Index 0: splash
                        _SplashWidget(onFinished: () {
                          ref.read(authControllerProvider.notifier).setStep(AuthStep.login);
                        }),
                        const _LoginCredentialsWidget(),
                        const _PhoneLoginWidget(),
                        const _PhoneLoginOtpWidget(),
                        const _CreateAccountCredentialsWidget(),
                        const _PhoneInputWidget(),
                        const _OtpInputWidget(),
                        const _RoleSelectionWidget(),
                        const _LocationWidget(),
                        const _RoleDetailsWidget(),
                        const _CompleteSuccessWidget(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Global loading blocker
            if (authState.isLoading)
              Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpinKitSquareCircle(
                        color: AppTheme.primaryColor,
                        size: 50.0,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'SECURELY SYNCING WITH ARENA...',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthState state) {
    final step = state.currentStep;
    // Recovery/login steps don't show a numbered progress counter
    final isRecoveryStep = step == AuthStep.login ||
        step == AuthStep.phoneLogin ||
        step == AuthStep.phoneLoginOtp;

    // For onboarding steps: count from createAccountCredentials (4) to roleDetails (9) = 6 steps
    const onboardingStart = AuthStep.createAccountCredentials;
    final onboardingIndex = step.index - onboardingStart.index;
    const totalOnboardingSteps = 6; // credentials→phoneInput→otpInput→roleSelection→location→roleDetails

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (shown for all steps except the primary login screen)
          if (step != AuthStep.login)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () async {
                if (step == AuthStep.createAccountCredentials) {
                  ref.read(authControllerProvider.notifier).goBackToLogin();
                } else if (step == AuthStep.phoneInput) {
                  final shouldExit = await _showExitConfirmationDialog();
                  if (shouldExit) {
                    await ref.read(authControllerProvider.notifier).exitOnboarding();
                  }
                } else if (step == AuthStep.phoneLoginOtp && state.phoneLinkedAccounts.isNotEmpty) {
                  ref.read(authControllerProvider.notifier).clearPhoneLinkedAccounts();
                } else {
                  ref.read(authControllerProvider.notifier).previousStep();
                }
              },
            )
          else
            const SizedBox(width: 40),

          // Central Title logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(18, 18),
                painter: AtheleosLogoPainter(),
              ),
              const SizedBox(width: 8),
              Text(
                'ATHELEOS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Step progress shown only for onboarding steps
          if (!isRecoveryStep && onboardingIndex >= 0 && onboardingIndex < totalOnboardingSteps)
            Text(
              '${onboardingIndex + 1}/$totalOnboardingSteps',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Text(
            'Exit Onboarding?',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Your profile hasn't been created yet. Exiting now will delete your progress and registration details. Are you sure you want to exit?",
            style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.spaceGrotesk(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Exit & Delete',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}



// STEP 0: SPLASH SCREEN
class _SplashWidget extends StatefulWidget {
  final VoidCallback onFinished;
  const _SplashWidget({required this.onFinished});

  @override
  State<_SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<_SplashWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.fastOutSlowIn),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );

    _animController.forward();

    // When the splash animation finishes, auto-advance to login
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(130, 130),
                painter: AtheleosLogoPainter(),
              ),
              const SizedBox(height: 32),
              Text(
                'ATHELEOS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'TRAIN. CONNECT. INSPIRE.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 48),
              const SpinKitThreeBounce(
                color: AppTheme.primaryColor,
                size: 20.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// STEP 1: USERNAME OR EMAIL + PASSWORD LOGIN
class _LoginCredentialsWidget extends ConsumerStatefulWidget {
  const _LoginCredentialsWidget();

  @override
  ConsumerState<_LoginCredentialsWidget> createState() =>
      _LoginCredentialsWidgetState();
}

class _LoginCredentialsWidgetState
    extends ConsumerState<_LoginCredentialsWidget> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  Map<String, String>? _savedCredentials;
  bool _hasFullSavedCredentials = false;
  bool _showManualInputs = false;
  bool _isDirectSigningIn = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  Future<void> _loadSavedAccount() async {
    final creds =
        await ref.read(authControllerProvider.notifier).getSavedCredentials();
    if (creds != null && mounted) {
      final hasPassword =
          creds['password'] != null && creds['password']!.isNotEmpty;
      setState(() {
        _savedCredentials = creds;
        _hasFullSavedCredentials = hasPassword;
        _showManualInputs = !hasPassword;
        _identifierController.text = creds['identifier'] ?? '';
      });
    } else if (mounted) {
      setState(() {
        _showManualInputs = true;
      });
    }
  }

  Future<void> _handleDirectSavedSignIn() async {
    setState(() => _isDirectSigningIn = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .directSignInWithSavedAccount();
    } finally {
      if (mounted) {
        setState(() => _isDirectSigningIn = false);
      }
    }
  }

  Future<void> _forgetSavedAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          'Remove Saved Account?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will remove your saved credentials from this device. You will need to enter your password next time you sign in.',
          style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authControllerProvider.notifier).clearSavedCredentials();
      setState(() {
        _savedCredentials = null;
        _hasFullSavedCredentials = false;
        _showManualInputs = true;
        _identifierController.clear();
        _passwordController.clear();
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      ref.read(authControllerProvider.notifier).loginWithUsernameOrEmail(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
            saveCredentials: _rememberMe,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: AtheleosLogoPainter(),
                ),
              ),
              const SizedBox(height: 16),

              if (_hasFullSavedCredentials && !_showManualInputs) ...[
                // ─────────────────────────────────────────────────────────────
                // 1-TAP SAVED ACCOUNT SIGN-IN SCREEN
                // ─────────────────────────────────────────────────────────────
                Text(
                  'WELCOME BACK',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back! Ready to crush your goals today?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                if (authState.errorMessage != null) ...[
                  _buildErrorBanner(authState.errorMessage!),
                  const SizedBox(height: 16),
                ],

                // Hero Saved Account Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Badge & Remove Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'SAVED ON DEVICE',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                            tooltip: 'Remove saved account',
                            onPressed: _forgetSavedAccount,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // User Profile Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                AppTheme.primaryColor.withOpacity(0.2),
                            child: Text(
                              ((_savedCredentials!['fullName']?.isNotEmpty ??
                                          false)
                                      ? _savedCredentials!['fullName']![0]
                                      : 'U')
                                  .toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _savedCredentials!['fullName'] ??
                                      'Atheleos User',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 17,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${_savedCredentials!['username']}',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (_savedCredentials!['role'] ?? 'ATHLETE')
                                        .toUpperCase(),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 1-TAP SIGN IN ACTION BUTTON
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor:
                                AppTheme.primaryColor.withOpacity(0.4),
                          ),
                          onPressed: _isDirectSigningIn
                              ? null
                              : _handleDirectSavedSignIn,
                          child: _isDirectSigningIn
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.flash_on_rounded,
                                        size: 20, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CONTINUE AS @${(_savedCredentials!['username'] ?? 'USER').toUpperCase()}',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Switch Account Option
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showManualInputs = true;
                          });
                        },
                        child: Text(
                          'Switch Account / Enter Password',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ─────────────────────────────────────────────────────────────
                // MANUAL INPUTS / GOOGLE AUTOFILL MODE
                // ─────────────────────────────────────────────────────────────
                Text(
                  'WELCOME TO ARENA',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock Your True Potential with Atheleos. Sign in to access your athlete combine stats, scouting reports, and network.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Return to Saved Account Banner if available
                if (_hasFullSavedCredentials) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showManualInputs = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Use saved 1-Tap sign in for @${_savedCredentials!['username']}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: AppTheme.primaryColor, size: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (authState.errorMessage != null) ...[
                  _buildErrorBanner(authState.errorMessage!),
                  const SizedBox(height: 16),
                ],

                AutofillGroup(
                  onDisposeAction: AutofillContextAction.commit,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Username or Email Field
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            labelText: 'Username or Email',
                            hintText:
                                'e.g. dynamic_player or player@atheleos.com',
                            prefixIcon: Icon(Icons.alternate_email,
                                color: AppTheme.primaryColor, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your username or email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.primaryColor, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Remember Me & Forgot Password Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: AppTheme.primaryColor,
                                      checkColor: Colors.black,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Remember credentials',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Primary SIGN IN Button
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _handleLogin,
                            child: Text(
                              'SIGN IN',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),


                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Divider OR
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                ],
              ),

              const SizedBox(height: 24),

              // Secondary: Phone Number Sign-in Option
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF333333)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .goToPhoneLogin(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_iphone,
                          color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'SIGN IN WITH MOBILE NUMBER',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Create Account Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Don\'t have an account? ',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(authControllerProvider.notifier)
                        .goToCreateAccount(),
                    child: Text(
                      'Create Account',
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}


// ════════════════════════════════════════════════════════════════════
// FALLBACK 2: PHONE LOGIN — MOBILE NUMBER ENTRY
// ════════════════════════════════════════════════════════════════════
class _PhoneLoginWidget extends StatefulWidget {
  const _PhoneLoginWidget();

  @override
  State<_PhoneLoginWidget> createState() => _PhoneLoginWidgetState();
}

class _PhoneLoginWidgetState extends State<_PhoneLoginWidget> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        return SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'SIGN IN WITH MOBILE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your registered mobile number. We will send a one-time code to verify your identity.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                if (authState.errorMessage != null)
                  _buildErrorBanner(authState.errorMessage!),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                            right: BorderSide(color: Color(0xFF222222))),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_iphone_outlined,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '+91',
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    hintText: 'Enter 10-digit number',
                    hintStyle: GoogleFonts.inter(color: Colors.white24),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final phone =
                            '+91${_phoneController.text.trim()}';
                        ref
                            .read(authControllerProvider.notifier)
                            .sendLoginOTP(phone);
                      }
                    },
                    child: Text(
                      'SEND OTP',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// FALLBACK 2 OTP: PHONE LOGIN — 6-DIGIT OTP ENTRY & ACCOUNT CHOOSER
// ════════════════════════════════════════════════════════════════════
class _PhoneLoginOtpWidget extends ConsumerStatefulWidget {
  const _PhoneLoginOtpWidget();

  @override
  ConsumerState<_PhoneLoginOtpWidget> createState() => _PhoneLoginOtpWidgetState();
}

class _PhoneLoginOtpWidgetState extends ConsumerState<_PhoneLoginOtpWidget> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());
  String _smsCode = '';

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _smsCode = _controllers.map((c) => c.text).join();
    });
  }

  Widget _buildAccountChooser(BuildContext context, AuthState authState) {
    final count = authState.phoneLinkedAccounts.length;
    final isSingle = count == 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Verified badge indicator
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.primaryColor,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PHONE VERIFIED',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSingle ? 'PROFILE FOUND' : 'SELECT ACCOUNT',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSingle
                ? 'We found 1 profile registered with ${authState.tempPhoneNumber}. Tap the card below to sign in:'
                : '$count profiles are linked with ${authState.tempPhoneNumber}. Tap the account you wish to access:',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ...authState.phoneLinkedAccounts.map((account) {
            return _buildAccountCard(context, account);
          }),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).goToPhoneLogin(),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white60),
              label: Text(
                'Use a different phone number',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).goBackToLogin(),
              child: Text(
                'Sign in with username or email',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, UserModel account) {
    final displayName = account.fullName.trim().isNotEmpty
        ? account.fullName.trim()
        : (account.username.isNotEmpty ? account.username : 'User');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final hasAvatar = account.avatarUrl.trim().isNotEmpty &&
        (account.avatarUrl.trim().startsWith('http://') ||
            account.avatarUrl.trim().startsWith('https://'));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.primaryColor.withOpacity(0.12),
          highlightColor: AppTheme.primaryColor.withOpacity(0.06),
          onTap: () {
            ref.read(authControllerProvider.notifier).selectPhoneAccount(account);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile picture / Avatar
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.6),
                      width: 1.8,
                    ),
                  ),
                  child: ClipOval(
                    child: hasAvatar
                        ? CachedNetworkImage(
                            imageUrl: account.avatarUrl.trim(),
                            fit: BoxFit.cover,
                            width: 54,
                            height: 54,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF222222),
                              child: const Center(
                                child: SpinKitPulse(
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildAvatarFallback(initial),
                          )
                        : _buildAvatarFallback(initial),
                  ),
                ),
                const SizedBox(width: 14),
                // Profile details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${account.username}',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (account.alternateEmail.isNotEmpty || account.googleEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          account.alternateEmail.isNotEmpty
                              ? account.alternateEmail
                              : account.googleEmail,
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (account.role.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                account.role.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (account.sport.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white12,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                account.sport,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Trailing login indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LOG IN',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryColor,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        if (authState.phoneLinkedAccounts.isNotEmpty) {
          return _buildAccountChooser(context, authState);
        }

        return SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'ENTER OTP',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: authState.tempPhoneNumber,
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (authState.errorMessage != null)
                _buildErrorBanner(authState.errorMessage!),

              // 6-box OTP grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _controllers[i].text.isNotEmpty
                                ? AppTheme.primaryColor
                                : const Color(0xFF222222),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        _onChanged();
                        if (v.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (v.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        if (_smsCode.length == 6) {
                          ref
                              .read(authControllerProvider.notifier)
                              .verifyLoginOTP(_smsCode);
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _smsCode.length == 6
                        ? AppTheme.primaryColor
                        : Colors.white12,
                    foregroundColor: _smsCode.length == 6
                        ? Colors.black
                        : Colors.white30,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _smsCode.length == 6
                      ? () => ref
                          .read(authControllerProvider.notifier)
                          .verifyLoginOTP(_smsCode)
                      : null,
                  child: Text(
                    'VERIFY & SIGN IN',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Didn\'t receive code? ',
                      style: TextStyle(color: Colors.white38)),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .sendLoginOTP(authState.tempPhoneNumber);
                    },
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SHARED HELPER — reusable error banner widget
// ─────────────────────────────────────────────────────────────────────
Widget _buildErrorBanner(String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
// STEP 4: CREATE ACCOUNT — CREDENTIALS & EMAIL VERIFICATION
// ════════════════════════════════════════════════════════════════════
class _CreateAccountCredentialsWidget extends ConsumerStatefulWidget {
  const _CreateAccountCredentialsWidget();

  @override
  ConsumerState<_CreateAccountCredentialsWidget> createState() =>
      _CreateAccountCredentialsWidgetState();
}

class _CreateAccountCredentialsWidgetState
    extends ConsumerState<_CreateAccountCredentialsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _emailOtpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && value.trim().length >= 3) {
        ref
            .read(authControllerProvider.notifier)
            .checkUsernameAvailability(value.trim());
      }
    });
  }

  void _sendEmailOtp() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    ref
        .read(authControllerProvider.notifier)
        .sendEmailVerificationOtp(email);
  }

  void _verifyEmailOtp() {
    final code = _emailOtpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }
    ref.read(authControllerProvider.notifier).verifyEmailOtp(code);
  }

  void _handleSubmit(AuthState authState) {
    if (!_formKey.currentState!.validate()) return;

    if (authState.isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a valid and available username'),
        ),
      );
      return;
    }

    if (!authState.isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please verify your email address with the OTP before proceeding'),
        ),
      );
      return;
    }

    TextInput.finishAutofillContext(shouldSave: true);
    ref.read(authControllerProvider.notifier).finalizeCredentialsAndProceed(
          username: _usernameController.text.trim(),
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.commit,
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CREATE ACCOUNT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Step 1 of registration: Set your identity, verify your email, and secure your credentials.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                if (authState.errorMessage != null)
                  _buildErrorBanner(authState.errorMessage!),

                // 1. ARENA USERNAME
                TextFormField(
                  controller: _usernameController,
                  onChanged: _onUsernameChanged,
                  autofillHints: const [
                    AutofillHints.newUsername,
                    AutofillHints.username,
                  ],
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Arena Username',
                    hintText: 'e.g. dynamic_player',
                    prefixIcon: const Icon(Icons.alternate_email,
                        color: AppTheme.primaryColor, size: 18),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (authState.isCheckingUsername)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          else if (authState.isUsernameAvailable == true)
                            const Icon(Icons.check_circle,
                                color: Colors.greenAccent, size: 20)
                          else if (authState.isUsernameAvailable == false)
                            const Icon(Icons.cancel,
                                color: Colors.redAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (val.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val.trim())) {
                      return 'Only letters, numbers, and underscores allowed';
                    }
                    if (authState.isUsernameAvailable == false) {
                      return 'This username is already taken';
                    }
                    return null;
                  },
                ),
                if (authState.isUsernameAvailable == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      '✓ @${_usernameController.text.trim()} is available',
                      style: GoogleFonts.inter(
                          color: Colors.greenAccent, fontSize: 11),
                    ),
                  )
                else if (authState.isUsernameAvailable == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      '✗ Username is already taken',
                      style: GoogleFonts.inter(
                          color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // 2. FULL NAME
                TextFormField(
                  controller: _fullNameController,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Alex Hunter',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppTheme.primaryColor, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. EMAIL ADDRESS (1 ACCOUNT PER EMAIL)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  enabled: !authState.isEmailVerified,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g. athlete@example.com',
                    prefixIcon: const Icon(Icons.mail_outline,
                        color: AppTheme.primaryColor, size: 18),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: authState.isEmailVerified
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.greenAccent, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            )
                          : TextButton(
                              onPressed: _sendEmailOtp,
                              child: Text(
                                authState.isEmailOtpSent
                                    ? 'Resend OTP'
                                    : 'Send OTP',
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Strict policy: 1 account per email address.',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. EMAIL OTP INPUT
                if (authState.isEmailOtpSent && !authState.isEmailVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mark_email_read_outlined,
                                color: AppTheme.primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'VERIFY EMAIL OTP',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter the 6-digit code sent to ${authState.tempEmail}:',
                          style: GoogleFonts.inter(
                              color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailOtpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 4,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '123456',
                                  counterText: '',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _verifyEmailOtp,
                              child: Text(
                                'VERIFY',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 5. PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  onChanged: (val) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 8 chars, A-Z, a-z, 0-9, symbol',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.primaryColor, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) => PasswordValidator.validate(val),
                ),
                const SizedBox(height: 10),
                PasswordRequirementsView(password: _passwordController.text),
                const SizedBox(height: 14),

                // 6. CONFIRM PASSWORD
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSubmit(authState),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_reset,
                        color: AppTheme.primaryColor, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // SUBMIT BUTTON
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleSubmit(authState),
                    child: Text(
                      'CONTINUE TO MOBILE VERIFICATION',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STEP 5: PHONE NUMBER INPUT (VALIDATES <= 5 ACCOUNTS LIMIT)
// ════════════════════════════════════════════════════════════════════
class _PhoneInputWidget extends StatefulWidget {
  const _PhoneInputWidget();

  @override
  State<_PhoneInputWidget> createState() => _PhoneInputWidgetState();
}

class _PhoneInputWidgetState extends State<_PhoneInputWidget> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'PHONE VERIFICATION',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Step 2: Atheleos allows up to 5 accounts linked to one phone number. We will send a one-time SMS verification code.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                if (authState.errorMessage != null)
                  _buildErrorBanner(authState.errorMessage!),

                // Phone Input Field with India prefix preset
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                            right: BorderSide(color: Color(0xFF222222))),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_iphone_outlined,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '+91',
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    hintText: 'Enter 10-digit number',
                    hintStyle: GoogleFonts.inter(color: Colors.white24),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final phone = '+91${_phoneController.text.trim()}';
                        ref
                            .read(authControllerProvider.notifier)
                            .sendRegistrationPhoneCode(phone);
                      }
                    },
                    child: Text(
                      'SEND SECURE OTP',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STEP 6: PHONE OTP VERIFICATION FOR REGISTRATION
// ════════════════════════════════════════════════════════════════════
class _OtpInputWidget extends StatefulWidget {
  const _OtpInputWidget();

  @override
  State<_OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<_OtpInputWidget> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());
  String _smsCode = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged() {
    String code = '';
    for (var controller in _controllers) {
      code += controller.text;
    }
    setState(() {
      _smsCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'ENTER VERIFICATION CODE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70, height: 1.5),
                  children: [
                    const TextSpan(
                        text: 'We sent a secure 6-digit confirmation PIN to '),
                    TextSpan(
                      text: authState.tempPhoneNumber,
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (authState.errorMessage != null)
                _buildErrorBanner(authState.errorMessage!),

              // SMS 6 blocks grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _controllers[index].text.isNotEmpty
                                ? AppTheme.primaryColor
                                : const Color(0xFF222222),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        _onCodeChanged();
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }

                        // Auto-submit on reaching 6 digits
                        if (_smsCode.length == 6) {
                          ref
                              .read(authControllerProvider.notifier)
                              .verifyRegistrationPhoneCode(_smsCode);
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _smsCode.length == 6
                        ? AppTheme.primaryColor
                        : Colors.white12,
                    foregroundColor: _smsCode.length == 6
                        ? Colors.black
                        : Colors.white30,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _smsCode.length == 6
                      ? () {
                          ref
                              .read(authControllerProvider.notifier)
                              .verifyRegistrationPhoneCode(_smsCode);
                        }
                      : null,
                  child: Text(
                    'VERIFY SECURITY CODE',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Didn\'t receive code? ',
                      style: TextStyle(color: Colors.white38)),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .sendRegistrationPhoneCode(
                              authState.tempPhoneNumber);
                    },
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Tip: Enter 123456 or any 6-digit pin in the sandbox to bypass.',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// STEP 4: ROLE SELECTION CARDS
class _RoleSelectionWidget extends StatefulWidget {
  const _RoleSelectionWidget();

  @override
  State<_RoleSelectionWidget> createState() => _RoleSelectionWidgetState();
}

class _RoleSelectionWidgetState extends State<_RoleSelectionWidget> {
  String _selectedRole = '';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SELECT YOUR ARENA ROLE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select your primary affiliation inside the Atheleos ecosystem. You can modify details later.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // ATHLETE CARD
              _buildRoleCard(
                roleName: 'Athlete',
                icon: Icons.emoji_events,
                description: 'Build your public stats card, upload drill combine clips, and get verified scouts to review your showcase videos.',
              ),
              const SizedBox(height: 16),

              // COACH CARD
              _buildRoleCard(
                roleName: 'Coach',
                icon: Icons.shield, // Athletic coach vibe
                description: 'Manage teams, search verified athlete data benchmarks, review direct combine film highlights, and invite prospects to camps.',
              ),
              const SizedBox(height: 16),

              // BRAND CARD
              _buildRoleCard(
                roleName: 'Brand',
                icon: Icons.business_center_outlined,
                description: 'Coordinate sports events, sponsor combines, issue brand contracts, and partner with top verified local talent pools.',
              ),
              const SizedBox(height: 16),

              // FEDERATION CARD
              _buildRoleCard(
                roleName: 'Federation',
                icon: Icons.account_balance_outlined,
                description: 'Official sports governing bodies and associations. Sanction tournaments, organize state/national meets, and verify competitive rosters.',
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole.isNotEmpty ? AppTheme.primaryColor : Colors.white12,
                    foregroundColor: _selectedRole.isNotEmpty ? Colors.black : Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _selectedRole.isNotEmpty 
                      ? () {
                          ref.read(authControllerProvider.notifier).selectRole(_selectedRole);
                        }
                      : null,
                  child: Text(
                    'CONFIRM PROFILE ROLE',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleCard({
    required String roleName,
    required IconData icon,
    required String description,
  }) {
    final isSelected = _selectedRole == roleName;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = roleName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1608) : const Color(0xFF121212),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFF222222),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected 
              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleName.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// STEP 5: LOCATION SELECTOR
class _LocationWidget extends StatefulWidget {
  const _LocationWidget();

  @override
  State<_LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<_LocationWidget> {
  String _selectedCountry = 'India';
  String _selectedState = '';
  String _selectedCity = '';
  final _pincodeController = TextEditingController();
  bool _isPincodeLoading = false;
  String? _pincodeError;

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _lookupPincode(String pincode) async {
    if (pincode.length != 6) return;
    setState(() {
      _isPincodeLoading = true;
      _pincodeError = null;
    });

    try {
      final response = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final status = data[0]['Status'];
          if (status == 'Success') {
            final postOffices = data[0]['PostOffice'];
            if (postOffices is List && postOffices.isNotEmpty) {
              final office = postOffices[0];
              final state = office['State'] ?? '';
              final city = office['District'] ?? office['Block'] ?? '';

              if (state.isNotEmpty && city.isNotEmpty) {
                setState(() {
                  _selectedState = state;
                  _selectedCity = city;
                  _isPincodeLoading = false;
                });
                return;
              }
            }
          }
        }
      }
      setState(() {
        _isPincodeLoading = false;
        _pincodeError = 'Invalid Pincode or no data found.';
      });
    } catch (e) {
      debugPrint('Pincode lookup error: $e');
      setState(() {
        _isPincodeLoading = false;
        _pincodeError = 'Failed to lookup pincode. Please try manually.';
      });
    }
  }

  // India standard sporting state hubs mapping for searchable lists
  final Map<String, List<String>> _indianStateCityMap = {
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik'],
    'Delhi NCR': ['New Delhi', 'Noida', 'Gurgaon', 'Faridabad'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Hubli', 'Mangaluru'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Salem'],
    'Punjab': ['Chandigarh', 'Ludhiana', 'Amritsar', 'Jalandhar'],
    'Haryana': ['Faridabad', 'Gurugram', 'Panipat', 'Rohtak'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad'],
    'Kerala': ['Kochi', 'Trivandrum', 'Kozhikode', 'Thrissur'],
    'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Siliguri'],
  };

  void _showSearchDialog({
    required String title,
    required List<String> items,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = items
                .where((element) => element.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search here...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                      fillColor: Colors.white10,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        query = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No dynamic items found.',
                              style: TextStyle(color: Colors.white24),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                tileColor: Colors.transparent,
                                title: Text(filteredItems[index], style: const TextStyle(color: Colors.white)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryColor),
                                onTap: () {
                                  onSelected(filteredItems[index]);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'YOUR REGIONAL HUB',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect locally. Atheleos custom-groups athletic leagues, local combines, and scouting boards by state and city centers.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Country Dropdown (ReadOnly)
              const Text(
                'Country',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _buildSelectorTile(_selectedCountry, isClickable: false),
              const SizedBox(height: 20),

              if (_selectedCountry == 'India') ...[
                const Text(
                  'PIN Code (India)',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit PIN Code',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.pin_drop, color: AppTheme.primaryColor, size: 16),
                    counterText: '',
                    suffixIcon: _isPincodeLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    if (val.trim().length == 6) {
                      _lookupPincode(val.trim());
                    } else {
                      setState(() {
                        _selectedState = '';
                        _selectedCity = '';
                      });
                    }
                  },
                ),
                if (_pincodeError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _pincodeError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              // State Dropdown
              const Text(
                'State / Region',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _buildSelectorTile(
                _selectedState.isEmpty ? 'Waiting for PIN Code...' : _selectedState,
                isClickable: false,
              ),
              const SizedBox(height: 20),

              // City Dropdown
              const Text(
                'City / Area',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _buildSelectorTile(
                _selectedCity.isEmpty ? 'Waiting for PIN Code...' : _selectedCity,
                isClickable: false,
              ),
              const SizedBox(height: 48),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedState.isNotEmpty && _selectedCity.isNotEmpty 
                        ? AppTheme.primaryColor 
                        : Colors.white12,
                    foregroundColor: _selectedState.isNotEmpty && _selectedCity.isNotEmpty 
                        ? Colors.black 
                        : Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _selectedState.isNotEmpty && _selectedCity.isNotEmpty
                      ? () {
                          ref.read(authControllerProvider.notifier).setLocation(
                            country: _selectedCountry,
                            stateName: _selectedState,
                            cityName: _selectedCity,
                          );
                        }
                      : null,
                  child: Text(
                    'LOCK IN REGION',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectorTile(String label, {bool isClickable = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isClickable ? const Color(0xFF121212) : const Color(0xFF1A1A1A),
        border: Border.all(color: isClickable ? const Color(0xFF222222) : const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: (label.startsWith('Select') || label.startsWith('Waiting'))
                  ? Colors.white30 
                  : (isClickable ? Colors.white : Colors.white60),
              fontSize: 14,
              fontWeight: (label.startsWith('Select') || label.startsWith('Waiting')) ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          if (isClickable)
            const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor, size: 18),
        ],
      ),
    );
  }
}

// STEP 6: ROLE SPECIFIC DETAILS
class _RoleDetailsWidget extends StatefulWidget {
  const _RoleDetailsWidget();

  @override
  State<_RoleDetailsWidget> createState() => _RoleDetailsWidgetState();
}

class _RoleDetailsWidgetState extends State<_RoleDetailsWidget> {
  final _sportController = TextEditingController();
  final _positionController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _recruitmentStatus;

  @override
  void dispose() {
    _sportController.dispose();
    _positionController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        final role = authState.currentUser.role;
        final isAthleteOrCoach = role == 'Athlete' || role == 'Coach';
        final isFederation = role == 'Federation';

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ROLE SPECIFIC DETAILS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isAthleteOrCoach
                    ? 'Fill in physical metrics or categories so scouts can locate you. You can skip any field for now.'
                    : isFederation
                        ? 'Specify your governing sport or administrative scope. You can update details anytime.'
                        : 'Specify your brand industry category or primary sport focus. You can update details anytime.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              if (authState.errorMessage != null) ...[
                _buildErrorBanner(authState.errorMessage!),
                const SizedBox(height: 16),
              ],

              if (role == 'Athlete' || role == 'Coach') ...[
                // Sport
                const Text('Sport Category', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SportSelectorField(
                  initialSport: _sportController.text,
                  hintText: 'Select Sport Category',
                  onSportChanged: (val) {
                    _sportController.text = val;
                  },
                ),
                const SizedBox(height: 16),

                // Position (Optional)
                const Text('Primary Position / Specialty (Optional)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _positionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Quarterback, Point Guard, Striker',
                    prefixIcon: Icon(Icons.star, color: AppTheme.primaryColor, size: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // Recruitment Status (Optional)
                const Text('Recruitment Status (Optional)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _recruitmentStatus,
                  dropdownColor: const Color(0xFF121212),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.how_to_reg, color: AppTheme.primaryColor, size: 16),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Uncommitted', child: Text('Uncommitted High School Prospect')),
                    DropdownMenuItem(value: 'Committed', child: Text('Committed College Athlete')),
                    DropdownMenuItem(value: 'Seeking Offers', child: Text('Seeking Scouting Offers')),
                    DropdownMenuItem(value: 'Professional', child: Text('Professional Agent Certified')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _recruitmentStatus = val;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Height & Weight Rows (Optional)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Height (Optional)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _heightController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 185 cm or 6\'1"',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Weight (Optional)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _weightController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 82 kg or 180 lbs',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (isFederation) ...[
                // Federation specific
                const Text('Governing Sport / Scope', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SportSelectorField(
                  initialSport: _sportController.text,
                  hintText: 'Select Governing Sport / Scope',
                  onSportChanged: (val) {
                    _sportController.text = val;
                  },
                ),
              ] else ...[
                // Brand specific
                const Text('Brand Sport / Industry Category', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SportSelectorField(
                  initialSport: _sportController.text,
                  hintText: 'Select Industry/Sport',
                  onSportChanged: (val) {
                    _sportController.text = val;
                  },
                ),
              ],
              const SizedBox(height: 40),

              // Action Buttons
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Save real details
                    ref.read(authControllerProvider.notifier).submitRoleDetails(
                      sport: _sportController.text.trim().isEmpty ? 'Multi-Sport' : _sportController.text.trim(),
                      position: _positionController.text.trim(),
                      recruitmentStatus: _recruitmentStatus,
                      height: _heightController.text.trim(),
                      weight: _weightController.text.trim(),
                      skipped: false,
                    );
                  },
                  child: Text(
                    'COMPLETE REGISTRATION',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Skip for now button
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Trigger skip, mark incomplete
                    ref.read(authControllerProvider.notifier).submitRoleDetails(
                      sport: '',
                      skipped: true,
                    );
                  },
                  child: Text(
                    'SKIP FOR NOW',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// STEP 7: COMPLETE AND SUCCESS
class _CompleteSuccessWidget extends StatefulWidget {
  const _CompleteSuccessWidget();

  @override
  State<_CompleteSuccessWidget> createState() => _CompleteSuccessWidgetState();
}

class _CompleteSuccessWidgetState extends State<_CompleteSuccessWidget> with SingleTickerProviderStateMixin {
  late AnimationController _radialController;
  late Animation<double> _radialAnimation;

  @override
  void initState() {
    super.initState();
    _radialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _radialAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _radialController, curve: Curves.fastOutSlowIn),
    );
    _radialController.forward();
  }

  @override
  void dispose() {
    _radialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        final completion = authState.currentUser.profileCompletion;
        final isComplete = completion >= 80;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Celebratory graphic block
              Center(
                child: ScaleTransition(
                  scale: _radialAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: completion / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completion%',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'COMPLETED',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              Text(
                'PROFILE SYNCHRONIZED!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isComplete 
                    ? 'Welcome to the premium athletic arena, Athlete. Your secure verified credentials have been synced with our high-performance scout servers.'
                    : 'Your account is active. To maximize your recruitment outreach and unlock advanced scouts, please complete your achievements, height, weight, and position inside your Profile completion later.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // LinkedIn style completion summary widget
              if (!isComplete) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    border: Border.all(color: const Color(0xFF222222)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: AppTheme.primaryColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'PENDING ARENA METRICS',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPendingBullet('Verify athletic height & weight'),
                      _buildPendingBullet('Input verified sport category and position'),
                      _buildPendingBullet('Attach recruitment status'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              const Spacer(),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Navigate directly to main App Home
                    context.go('/home');
                  },
                  child: Text(
                    'ENTER THE ARENA',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white38)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
