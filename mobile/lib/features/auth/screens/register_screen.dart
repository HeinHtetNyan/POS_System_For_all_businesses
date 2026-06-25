import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Password hint state (driven by current password value)
  bool get _has8Chars => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordController.text.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    // Rebuild password hints as user types
    _passwordController.addListener(() => setState(() {}));
    // Force referral code to uppercase
    _referralCodeController.addListener(() {
      final upper = _referralCodeController.text.toUpperCase();
      if (_referralCodeController.text != upper) {
        _referralCodeController.value = _referralCodeController.value.copyWith(
          text: upper,
          selection: TextSelection.collapsed(offset: upper.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final biz = _businessNameController.text.trim();
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (biz.length < 2) return false;
    if (first.isEmpty) return false;
    if (last.isEmpty) return false;
    if (!email.contains('@')) return false;
    if (!_has8Chars || !_hasUppercase || !_hasLowercase || !_hasDigit) {
      return false;
    }
    if (pass != confirm) return false;
    return true;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final referral = _referralCodeController.text.trim();

      final payload = <String, dynamic>{
        'business_name': _businessNameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };
      if (phone.isNotEmpty) payload['phone'] = phone;
      if (referral.isNotEmpty) payload['referral_code'] = referral.toUpperCase();

      final response = await apiClient.post('/auth/register', data: payload);
      final data = response.data as Map<String, dynamic>;

      final accessToken = data['access_token'] as String?;
      if (accessToken != null) {
        // Save the token using the same SecureStorage slot that AuthNotifier
        // reads from, then fetch the user profile and persist it.
        final storage = SecureStorage();
        await storage.saveAccessToken(accessToken);

        final userResponse = await apiClient.get(ApiEndpoints.me);
        final user = UserModel.fromJson(
            userResponse.data as Map<String, dynamic>);
        await storage.saveUserJson(jsonEncode(user.toJson()));

        // Reload auth state — the router's refreshListenable fires and
        // GoRouter's redirect picks up the authenticated user automatically.
        if (mounted) {
          await ref.read(authProvider.notifier).initialize();
        }
      } else {
        // No token returned — navigate to login
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please sign in.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/login');
        }
      }
    } on AppException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _passwordHintRow(String label, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: satisfied ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: satisfied ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // Logo section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryFg,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SawYun POS',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Registration card
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Business Name
                        TextFormField(
                          controller: _businessNameController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Business Name',
                            prefixIcon: const Icon(Icons.business_outlined,
                                color: AppColors.textSecondary, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 2) {
                              return 'Business name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // First Name + Last Name (side by side)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'First Name',
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: AppColors.textSecondary, size: 18),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Last Name',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: AppColors.textSecondary, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Phone (optional)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Phone (optional)',
                            prefixIcon: const Icon(Icons.phone_outlined,
                                color: AppColors.textSecondary, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined,
                                color: AppColors.textSecondary, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!v.contains(RegExp(r'[A-Z]'))) {
                              return 'Password must contain an uppercase letter';
                            }
                            if (!v.contains(RegExp(r'[a-z]'))) {
                              return 'Password must contain a lowercase letter';
                            }
                            if (!v.contains(RegExp(r'[0-9]'))) {
                              return 'Password must contain a digit';
                            }
                            return null;
                          },
                        ),

                        // Password inline hints
                        if (_passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _passwordHintRow(
                                    'At least 8 characters', _has8Chars),
                                _passwordHintRow(
                                    'Has uppercase letter', _hasUppercase),
                                _passwordHintRow(
                                    'Has lowercase letter', _hasLowercase),
                                _passwordHintRow('Has digit', _hasDigit),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outlined,
                                color: AppColors.textSecondary, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Referral Code (optional)
                        TextFormField(
                          controller: _referralCodeController,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              letterSpacing: 1.2),
                          decoration: _inputDecoration(
                            label: 'Referral Code (optional)',
                            hintText: 'e.g. REF-ABCD1234',
                            prefixIcon: const Icon(Icons.card_giftcard_outlined,
                                color: AppColors.textSecondary, size: 18),
                          ),
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _register();
                          },
                        ),

                        const SizedBox(height: 24),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                (_isLoading || !_isFormValid) ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.primaryFg,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              disabledForegroundColor:
                                  AppColors.primaryFg.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

