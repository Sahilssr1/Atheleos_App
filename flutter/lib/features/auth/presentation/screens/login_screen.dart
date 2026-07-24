import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sport_selector_field.dart';
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
      _pageController.animateToPage(
        step.index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

    return Scaffold(
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
                      const _LoginGoogleWidget(),
                      const _AlternateEmailLoginWidget(),
                      const _PhoneLoginWidget(),
                      const _PhoneLoginOtpWidget(),
                      const _PhoneInputWidget(),
                      const _OtpInputWidget(),
                      const _BasicAccountWidget(),
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
    );
  }

  Widget _buildHeader(BuildContext context, AuthState state) {
    final step = state.currentStep;
    // Recovery/login steps don't show a numbered progress counter
    final isRecoveryStep = step == AuthStep.login ||
        step == AuthStep.alterEmailLogin ||
        step == AuthStep.phoneLogin ||
        step == AuthStep.phoneLoginOtp;

    // For onboarding steps: count from phoneInput (5) to roleDetails (10) = 6 steps
    const onboardingStart = AuthStep.phoneInput;
    final onboardingIndex = step.index - onboardingStart.index;
    const totalOnboardingSteps = 6; // phoneInput→otpInput→basicAccount→roleSelection→location→roleDetails

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (shown for all steps except the primary login screen)
          if (step != AuthStep.login)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () {
                ref.read(authControllerProvider.notifier).previousStep();
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
}

// ATHELEOS GOLD LOGO PAINTER
class AtheleosLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;

    final path = Path();
    // High-tech, sharp stylized athletic letter "A"
    path.moveTo(size.width * 0.5, size.height * 0.05);
    path.lineTo(size.width * 0.2, size.height * 0.95);
    path.lineTo(size.width * 0.35, size.height * 0.95);
    path.lineTo(size.width * 0.5, size.height * 0.45);
    path.lineTo(size.width * 0.65, size.height * 0.95);
    path.lineTo(size.width * 0.8, size.height * 0.95);
    path.close();

    // Sharp cross-cutting horizontal graphic block
    path.moveTo(size.width * 0.38, size.height * 0.68);
    path.lineTo(size.width * 0.62, size.height * 0.68);
    path.lineTo(size.width * 0.68, size.height * 0.77);
    path.lineTo(size.width * 0.32, size.height * 0.77);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

// STEP 1: CONTINUE WITH GOOGLE SCREEN
class _LoginGoogleWidget extends ConsumerWidget {
  const _LoginGoogleWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
      child: Column(
        children: [
          const Spacer(),
          // Giant premium branding
          CustomPaint(
            size: const Size(100, 100),
            painter: AtheleosLogoPainter(),
          ),
          const SizedBox(height: 24),
          Text(
            'ATHELEOS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'THE PREMIUM ATHLETIC ARENA',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          Text(
            'WELCOME TO THE FUTURE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with top-tier coaches, scout elite prospects, and monetize your combine highlights.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          if (authState.errorMessage != null)
            Container(
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
                      authState.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Google Sign-In primary option
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () {
                ref.read(authControllerProvider.notifier).signInWithGoogle();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CONTINUE WITH GOOGLE',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          GestureDetector(
            onTap: () =>
                ref.read(authControllerProvider.notifier).goToAlternateEmailLogin(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.help_outline,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Forgot Google account?',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white38,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Sign in another way',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'By signing in, you agree to the Atheleos Athlete Code of Conduct and Verified Recruitment Agreements.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white38,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AlternateEmailLoginWidget extends StatefulWidget {
  const _AlternateEmailLoginWidget();

  @override
  State<_AlternateEmailLoginWidget> createState() =>
      _AlternateEmailLoginWidgetState();
}

class _AlternateEmailLoginWidgetState
    extends State<_AlternateEmailLoginWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _resetSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                // Header badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset,
                          color: AppTheme.primaryColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'RECOVERY PATH 1 OF 2',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'SIGN IN WITH EMAIL',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the alternate recovery email you set during registration to sign in.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                if (authState.errorMessage != null)
                  _buildErrorBanner(authState.errorMessage!),

                if (_resetSent)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border:
                          Border.all(color: Colors.green.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mark_email_read_outlined,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Password reset link sent! Check your inbox.',
                            style: GoogleFonts.inter(
                                color: Colors.green, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Alternate Email',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppTheme.primaryColor, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.primaryColor, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: Colors.white38,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32)),
                    onPressed: () async {
                      if (_emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Enter your email above first, then tap Forgot Password.'),
                          ),
                        );
                        return;
                      }
                      final error = await ref
                          .read(authControllerProvider.notifier)
                          .sendPasswordResetEmail(
                              _emailController.text.trim());
                      if (mounted) {
                        if (error == null) {
                          setState(() => _resetSent = true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
                      }
                    },
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign In button
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
                        ref
                            .read(authControllerProvider.notifier)
                            .signInWithAlternateEmail(
                              email: _emailController.text.trim(),
                              password: _passwordController.text,
                            );
                      }
                    },
                    child: Text(
                      'SIGN IN',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),

                // ── Forgot this email too? ────────────────────────────
                const SizedBox(height: 28),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Forgot this email too?',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
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
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .goToPhoneLogin(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset,
                          color: AppTheme.primaryColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'RECOVERY PATH 2 OF 2',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
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
                            '+91\${_phoneController.text.trim()}';
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
// FALLBACK 2 OTP: PHONE LOGIN — 6-DIGIT OTP ENTRY
// ════════════════════════════════════════════════════════════════════
class _PhoneLoginOtpWidget extends StatefulWidget {
  const _PhoneLoginOtpWidget();

  @override
  State<_PhoneLoginOtpWidget> createState() => _PhoneLoginOtpWidgetState();
}

class _PhoneLoginOtpWidgetState extends State<_PhoneLoginOtpWidget> {
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
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
                  'Atheleos requires a verified mobile number to secure recruitment contacts and avoid bots.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                if (authState.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),

                // Phone Input Field with India prefix preset
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFF222222))),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_iphone_outlined, color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '+91',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final phone = '+91${_phoneController.text.trim()}';
                        ref.read(authControllerProvider.notifier).sendVerificationCode(phone);
                      }
                    },
                    child: Text(
                      'SEND SECURE OTP',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
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

// STEP 2 (OTP): OTP CODES INPUTS
class _OtpInputWidget extends StatefulWidget {
  const _OtpInputWidget();

  @override
  State<_OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<_OtpInputWidget> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
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
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a secure 6-digit confirmation PIN to '),
                    TextSpan(
                      text: authState.tempPhoneNumber,
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (authState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),

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
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
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
                          ref.read(authControllerProvider.notifier).verifyOTPCode(_smsCode);
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
                    backgroundColor: _smsCode.length == 6 ? AppTheme.primaryColor : Colors.white12,
                    foregroundColor: _smsCode.length == 6 ? Colors.black : Colors.white30,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _smsCode.length == 6 
                      ? () {
                          ref.read(authControllerProvider.notifier).verifyOTPCode(_smsCode);
                        }
                      : null,
                  child: Text(
                    'VERIFY SECURITY CODE',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Didn\'t receive code? ', style: TextStyle(color: Colors.white38)),
                  TextButton(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).sendVerificationCode(authState.tempPhoneNumber);
                    },
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Tip: Enter 123456 or any 6-digit pin in the sandbox to bypass.',
                  style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// STEP 3: CREATE PREMIUM SPORTS PROFILE
class _BasicAccountWidget extends StatefulWidget {
  const _BasicAccountWidget();

  @override
  State<_BasicAccountWidget> createState() => _BasicAccountWidgetState();
}

class _BasicAccountWidgetState extends State<_BasicAccountWidget> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _alternateEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  double _passwordStrength = 0; // 0 to 1
  String _passwordStrengthLabel = 'Empty';
  Color _passwordStrengthColor = Colors.white24;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _alternateEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _assessPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthLabel = 'Empty';
        _passwordStrengthColor = Colors.white24;
      });
      return;
    }
    double score = 0;
    if (password.length >= 6) score += 0.2;
    if (password.length >= 10) score += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.2;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) score += 0.2;

    setState(() {
      _passwordStrength = score;
      if (score <= 0.4) {
        _passwordStrengthLabel = 'Weak';
        _passwordStrengthColor = Colors.redAccent;
      } else if (score <= 0.8) {
        _passwordStrengthLabel = 'Medium';
        _passwordStrengthColor = Colors.amberAccent;
      } else {
        _passwordStrengthLabel = 'Strong Athlete Strength';
        _passwordStrengthColor = AppTheme.primaryColor;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CREATE PREMIUM PROFILE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set up your unique credentials to unlock our high-performance scout and recruitment network.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                if (authState.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Arena Username',
                    prefixIcon: Icon(Icons.alternate_email, color: AppTheme.primaryColor, size: 16),
                    hintText: 'e.g. dynamic_quarterback',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (value.trim().length < 4) {
                      return 'Username must be at least 4 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                      return 'Only letters, numbers, and underscores are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Full Name Field
                TextFormField(
                  controller: _fullNameController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor, size: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Alternate Email
                TextFormField(
                  controller: _alternateEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Alternate Recovery Email',
                    prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor, size: 16),
                    helperText: 'For safety if you lose your Google account access.',
                    helperStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Alternate recovery email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Recovery Password',
                    prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor, size: 16),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: Colors.white38,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onChanged: _assessPasswordStrength,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),

                // Password strength bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Password Strength:', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text(
                          _passwordStrengthLabel,
                          style: TextStyle(color: _passwordStrengthColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor, size: 16),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: Colors.white38,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ref.read(authControllerProvider.notifier).createBasicAccount(
                          username: _usernameController.text,
                          fullName: _fullNameController.text,
                          alternateEmail: _alternateEmailController.text,
                          password: _passwordController.text,
                        );
                      }
                    },
                    child: Text(
                      'CONTINUE TO ROLES',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
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

              // BRAND / FEDERATION CARD
              _buildRoleCard(
                roleName: 'Brand / Federation',
                icon: Icons.business,
                description: 'Coordinate sports events, sponsor combines, issue brand contracts, and partner with top verified local talent pools.',
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

              // Country Dropdown (ReadOnly searchable)
              const Text(
                'Country',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  _showSearchDialog(
                    title: 'Select Country',
                    items: ['India', 'United States', 'United Kingdom', 'Australia', 'South Africa'],
                    onSelected: (val) {
                      setState(() {
                        _selectedCountry = val;
                        _selectedState = '';
                        _selectedCity = '';
                      });
                    },
                  );
                },
                child: _buildSelectorTile(_selectedCountry),
              ),
              const SizedBox(height: 20),

              // State Dropdown
              const Text(
                'State / Region',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  if (_selectedCountry != 'India') {
                    _showSearchDialog(
                      title: 'Select Region',
                      items: ['California', 'Texas', 'New York', 'London Region', 'New South Wales'],
                      onSelected: (val) {
                        setState(() {
                          _selectedState = val;
                          _selectedCity = '';
                        });
                      },
                    );
                    return;
                  }
                  _showSearchDialog(
                    title: 'Select Indian State',
                    items: _indianStateCityMap.keys.toList(),
                    onSelected: (val) {
                      setState(() {
                        _selectedState = val;
                        _selectedCity = '';
                      });
                    },
                  );
                },
                child: _buildSelectorTile(_selectedState.isEmpty ? 'Select State' : _selectedState),
              ),
              const SizedBox(height: 20),

              // City Dropdown
              const Text(
                'City / Area',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  if (_selectedState.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a State first.')),
                    );
                    return;
                  }
                  if (_selectedCountry != 'India') {
                    _showSearchDialog(
                      title: 'Select City',
                      items: ['Los Angeles', 'Houston', 'Dallas', 'Austin', 'Brooklyn', 'Manhattan', 'Sydney', 'Cape Town'],
                      onSelected: (val) {
                        setState(() {
                          _selectedCity = val;
                        });
                      },
                    );
                    return;
                  }
                  _showSearchDialog(
                    title: 'Select City',
                    items: _indianStateCityMap[_selectedState] ?? [],
                    onSelected: (val) {
                      setState(() {
                        _selectedCity = val;
                      });
                    },
                  );
                },
                child: _buildSelectorTile(_selectedCity.isEmpty ? 'Select City' : _selectedCity),
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

  Widget _buildSelectorTile(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border.all(color: const Color(0xFF222222)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: label.startsWith('Select') ? Colors.white30 : Colors.white,
              fontSize: 14,
              fontWeight: label.startsWith('Select') ? FontWeight.normal : FontWeight.bold,
            ),
          ),
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
                'Fill in physical metrics or categories so scouts can locate you. You can skip any field for now.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

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
