import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/password_validator.dart';
import '../../../../core/widgets/password_requirements_view.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import 'edit_profile_screen.dart';
import '../../../../core/utils/user_facing_error.dart';

class EditProfileSettingsRoute extends ConsumerWidget {
  const EditProfileSettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(activeProfileProvider).when(
          loading: () => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: Text('$error')),
          ),
          data: (ProfileModel? profile) => profile == null
              ? const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: Text('Profile not found.')),
                )
              : EditProfileScreen(profile: profile),
        );
  }
}

class ChangeUsernameScreen extends ConsumerStatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  ConsumerState<ChangeUsernameScreen> createState() =>
      _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends ConsumerState<ChangeUsernameScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _message = '';
  bool _available = false;
  bool _checking = false;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _check(String value) {
    _debounce?.cancel();
    final actions = ref.read(accountActionsProvider);
    final validation = actions.validateUsername(value);
    if (validation.isNotEmpty) {
      setState(() {
        _message = validation;
        _available = false;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final available = await actions.isUsernameAvailable(value);
        if (!mounted || value != _controller.text) return;
        setState(() {
          _available = available;
          _checking = false;
          _message = available
              ? 'Username is available.'
              : 'Username is already taken.';
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _available = false;
          _message = _friendlyError(error);
        });
      }
    });
  }

  Future<void> _save() async {
    if (!_available || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(accountActionsProvider).changeUsername(_controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = _friendlyError(error);
        _available = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'CHANGE USERNAME',
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          onChanged: _check,
          decoration: InputDecoration(
            labelText: 'Username',
            prefixText: '@',
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _message.isEmpty
                    ? null
                    : Icon(
                        _available ? Icons.check_circle : Icons.error_outline,
                        color:
                            _available ? Colors.greenAccent : Colors.redAccent,
                      ),
          ),
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _message,
            style: TextStyle(
              color: _available ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '3-30 characters. Start with a letter or number. Letters, numbers, periods, and underscores are allowed.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Save Username',
          loading: _saving,
          onPressed: _available ? _save : null,
        ),
      ],
    );
  }
}

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!_isEmail(email)) {
      _showError(context, 'Enter a valid email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).changeEmail(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  Future<void> _complete() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(accountActionsProvider)
          .completeEmailChange(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address verified and updated.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'CHANGE EMAIL',
      children: [
        TextField(
          controller: _emailController,
          enabled: !_sent,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'New email address'),
        ),
        const SizedBox(height: 12),
        Text(
          _sent
              ? 'Open the link sent to ${_emailController.text.trim()}, then return here to finish.'
              : 'Firebase Authentication must verify the new address before your profile is updated.',
          style:
              const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: _sent ? 'I Have Verified My Email' : 'Send Verification Email',
          loading: _loading,
          onPressed: _sent ? _complete : _send,
        ),
        if (_sent)
          TextButton(
            onPressed: _loading ? null : _send,
            child: const Text('Resend verification email'),
          ),
      ],
    );
  }
}

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final bool recoveryPhone;

  const PhoneVerificationScreen({super.key, this.recoveryPhone = false});

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _showError(
          context, 'Use international format, for example +14155552671.');
      return;
    }
    setState(() => _loading = true);
    await ref.read(accountActionsProvider).sendPhoneUpdateOTP(
          phoneNumber: phone,
          onCodeSent: (verificationId) {
            if (!mounted) return;
            setState(() {
              _verificationId = verificationId;
              _loading = false;
            });
          },
          onFailed: (error) {
            if (!mounted) return;
            setState(() => _loading = false);
            _showError(context, _friendlyError(error));
          },
        );
  }

  Future<void> _verify() async {
    if (_otpController.text.trim().length < 6 || _verificationId == null)
      return;
    setState(() => _loading = true);
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s()-]'), '');
    try {
      await ref.read(accountActionsProvider).verifyPhoneUpdateOTP(
            _verificationId!,
            _otpController.text.trim(),
            phone,
          );
      if (widget.recoveryPhone) {
        await ref.read(accountActionsProvider).setRecoveryPhone(phone);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.recoveryPhone
              ? 'Recovery phone verified.'
              : 'Phone number verified and updated.'),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null;
    return _SettingsFormScaffold(
      title: widget.recoveryPhone ? 'RECOVERY PHONE' : 'CHANGE PHONE',
      children: [
        TextField(
          controller: _phoneController,
          enabled: !codeSent,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+14155552671',
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration:
                const InputDecoration(labelText: '6-digit verification code'),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Standard SMS rates may apply. Firebase securely verifies the code before any account data changes.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: codeSent ? 'Verify Code' : 'Send Verification Code',
          loading: _loading,
          onPressed: codeSent ? _verify : _sendCode,
        ),
      ],
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _newController.text;
    final validationError = PasswordValidator.validate(password);
    if (validationError != null) {
      _showError(context, validationError);
      return;
    }
    if (password != _confirmController.text) {
      _showError(context, 'New passwords do not match.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).changePassword(
            _currentController.text,
            password,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'CHANGE PASSWORD',
      children: [
        _PasswordField(
            controller: _currentController, label: 'Current password'),
        const SizedBox(height: 12),
        _PasswordField(
          controller: _newController,
          label: 'New password',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        PasswordRequirementsView(password: _newController.text),
        const SizedBox(height: 12),
        _PasswordField(
            controller: _confirmController, label: 'Confirm new password'),
        const SizedBox(height: 24),
        _PrimaryButton(
            label: 'Update Password', loading: _loading, onPressed: _save),
      ],
    );
  }
}

class AlternateEmailScreen extends ConsumerStatefulWidget {
  const AlternateEmailScreen({super.key});

  @override
  ConsumerState<AlternateEmailScreen> createState() =>
      _AlternateEmailScreenState();
}

class _AlternateEmailScreenState extends ConsumerState<AlternateEmailScreen> {
  final _emailController = TextEditingController();
  final _linkController = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_isEmail(_emailController.text)) {
      _showError(context, 'Enter a valid backup email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(accountActionsProvider)
          .sendAlternateEmailVerification(_emailController.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).verifyAlternateEmail(
            _emailController.text,
            _linkController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alternate email verified and saved.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = ref.watch(accountRecoveryProvider).valueOrNull;
    return _SettingsFormScaffold(
      title: 'ALTERNATE EMAIL',
      children: [
        if ((recovery?['alternateEmail'] as String? ?? '').isNotEmpty) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified, color: Colors.greenAccent),
            title: Text(recovery!['alternateEmail'] as String),
            subtitle: const Text('Verified backup email'),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          enabled: !_sent,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Backup email address'),
        ),
        if (_sent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _linkController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Verification link',
              hintText: 'Paste the complete link from the email',
              alignLabelWithHint: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Your backup address is saved only after Firebase confirms ownership.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: _sent ? 'Verify and Save' : 'Send Verification Link',
          loading: _loading,
          onPressed: _sent ? _verify : _send,
        ),
      ],
    );
  }
}

class ConnectedAccountScreen extends ConsumerStatefulWidget {
  const ConnectedAccountScreen({super.key});

  @override
  ConsumerState<ConnectedAccountScreen> createState() =>
      _ConnectedAccountScreenState();
}

class _ConnectedAccountScreenState
    extends ConsumerState<ConnectedAccountScreen> {
  bool _loading = false;

  Future<void> _changeAccount() async {
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).refreshConnectedGoogleAccount();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected Google account refreshed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  Future<void> _disconnect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.providerData.length <= 1) {
      _showError(
          context, 'Add another sign-in method before disconnecting Google.');
      return;
    }
    setState(() => _loading = true);
    try {
      await user.unlink(GoogleAuthProvider.PROVIDER_ID);
      await user.reload();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final google = user?.providerData
        .where(
            (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID)
        .firstOrNull;
    return _SettingsFormScaffold(
      title: 'CONNECTED ACCOUNT',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: google?.photoURL == null
                ? null
                : NetworkImage(google!.photoURL!),
            child: google?.photoURL == null
                ? const Icon(Icons.account_circle)
                : null,
          ),
          title: Text(google?.displayName ?? 'Google account'),
          subtitle: Text(google?.email ?? 'Not connected'),
          trailing: Icon(
            google == null ? Icons.link_off : Icons.verified,
            color: google == null ? Colors.white38 : Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _changeAccount,
          child: const Text('Change Account'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: google == null || _loading ? null : _disconnect,
          child: Text(_loading ? 'Disconnecting...' : 'Disconnect Google'),
        ),
        const SizedBox(height: 12),
        const Text(
          'To change the connected Google identity, disconnect it after adding another sign-in method, then connect the preferred account during sign-in.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  bool get _requiresPassword =>
      FirebaseAuth.instance.currentUser?.providerData.any(
          (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID) ??
      false;

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirmationController.text.trim().toUpperCase() != 'DELETE') {
      _showError(context, 'Type DELETE to confirm.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).deleteAccount(
            password: _requiresPassword ? _passwordController.text : null,
          );
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'DELETE ACCOUNT',
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Your account will be marked as deleted and you will be signed out. Your historical Firestore data will be retained for platform integrity and future server-side cleanup. You will not be able to sign in again.',
          style: TextStyle(color: Colors.white70, height: 1.6),
        ),
        const SizedBox(height: 24),
        if (_requiresPassword) ...[
          _PasswordField(
              controller: _passwordController, label: 'Current password'),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _confirmationController,
          textCapitalization: TextCapitalization.characters,
          decoration:
              const InputDecoration(labelText: 'Type DELETE to confirm'),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Delete Account',
          loading: _loading,
          danger: true,
          onPressed: _delete,
        ),
      ],
    );
  }
}

class _SettingsFormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsFormScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: children,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool danger;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: danger
          ? ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white)
          : ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
            ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      ),
    );
  }
}

bool _isEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

String _friendlyError(Object error) {
  return UserFacingError.message(error);
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
  );
}
