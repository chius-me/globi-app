import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/globi_button.dart';
import '../widgets/globi_error_banner.dart';
import '../widgets/edge_swipe_back_container.dart';

enum _LocalAuthView { login, register, verifyEmail, resetPassword }

enum _LoginStage { methodSelection, emailFlow }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _resendCooldownSeconds = 60;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _verifyEmailController = TextEditingController();
  final _verifyCodeController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _resetNewPasswordController = TextEditingController();
  final _resetConfirmPasswordController = TextEditingController();

  _LoginStage _stage = _LoginStage.methodSelection;
  _LocalAuthView _view = _LocalAuthView.login;
  Timer? _verificationCooldownTimer;
  Timer? _resetCooldownTimer;
  int _verificationCooldownRemaining = 0;
  int _resetCooldownRemaining = 0;
  int? _verificationCodeTtlSeconds;

  @override
  void dispose() {
    _verificationCooldownTimer?.cancel();
    _resetCooldownTimer?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _verifyEmailController.dispose();
    _verifyCodeController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _resetNewPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetToHome(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await context.read<AppModeProvider>().resetMode();
  }

  void _setView(_LocalAuthView view, {bool clearError = true}) {
    FocusScope.of(context).unfocus();
    if (clearError) context.read<AuthProvider>().clearError();
    setState(() => _view = view);
  }

  void _openEmailFlow({_LocalAuthView initialView = _LocalAuthView.login}) {
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().clearError();
    setState(() {
      _stage = _LoginStage.emailFlow;
      _view = initialView;
    });
  }

  void _showMethodSelection() {
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().clearError();
    setState(() {
      _stage = _LoginStage.methodSelection;
      _view = _LocalAuthView.login;
    });
  }

  void _handleEmailFlowBack() {
    if (_view == _LocalAuthView.verifyEmail ||
        _view == _LocalAuthView.resetPassword) {
      _setView(_LocalAuthView.login);
      return;
    }
    _showMethodSelection();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '请输入邮箱';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed)) {
      return '请输入正确的邮箱';
    }
    return null;
  }

  String? _validatePassword(String? value, {required String label}) {
    if (value == null || value.isEmpty) return '请输入$label';
    return null;
  }

  String? _validateCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '请输入验证码';
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) return '请输入6位验证码';
    return null;
  }

  void _startCooldown(bool isVerification, [int seconds = _resendCooldownSeconds]) {
    final timer = isVerification ? _verificationCooldownTimer : _resetCooldownTimer;
    timer?.cancel();
    setState(() {
      if (isVerification) {
        _verificationCooldownRemaining = seconds;
      } else {
        _resetCooldownRemaining = seconds;
      }
    });
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (isVerification) {
          if (_verificationCooldownRemaining <= 1) {
            timer.cancel();
            _verificationCooldownRemaining = 0;
          } else {
            _verificationCooldownRemaining -= 1;
          }
        } else {
          if (_resetCooldownRemaining <= 1) {
            timer.cancel();
            _resetCooldownRemaining = 0;
          } else {
            _resetCooldownRemaining -= 1;
          }
        }
      });
    });
  }

  // ... action methods unchanged from original
  Future<void> _submitLocalLogin(AuthProvider auth) async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await auth.loginWithLocalAccount(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );
  }

  Future<void> _submitRegister(AuthProvider auth) async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) return;
    if (_registerPasswordController.text != _registerConfirmPasswordController.text) {
      _showMessage('两次密码输入不一致');
      return;
    }
    FocusScope.of(context).unfocus();
    final result = await auth.registerLocalAccount(
      email: _registerEmailController.text,
      password: _registerPasswordController.text,
    );
    if (result == null || !mounted) return;
    _verifyEmailController.text = result.email;
    _verifyCodeController.clear();
    _loginEmailController.text = result.email;
    setState(() {
      _view = _LocalAuthView.verifyEmail;
      _verificationCodeTtlSeconds = result.codeTtlSeconds > 0 ? result.codeTtlSeconds : null;
    });
    _startCooldown(true);
    _showMessage(result.emailSent ? '验证码已发送到 ${result.email}' : '注册成功，请输入邮箱验证码');
  }

  Future<void> _submitVerify(AuthProvider auth) async {
    if (!(_verifyFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final success = await auth.verifyLocalEmail(
      email: _verifyEmailController.text,
      code: _verifyCodeController.text,
    );
    if (!success || !mounted) return;
    _verifyCodeController.clear();
    _openEmailFlow(initialView: _LocalAuthView.login);
    _showMessage('邮箱验证完成，请使用邮箱密码登录');
  }

  Future<void> _resendVerification(AuthProvider auth) async {
    if (_verificationCooldownRemaining > 0) return;
    final emailError = _validateEmail(_verifyEmailController.text);
    if (emailError != null) { _showMessage(emailError); return; }
    FocusScope.of(context).unfocus();
    final success = await auth.resendLocalVerificationCode(email: _verifyEmailController.text);
    if (!success || !mounted) return;
    _startCooldown(true);
    _showMessage('验证码已重新发送');
  }

  Future<void> _sendResetCode(AuthProvider auth) async {
    final emailError = _validateEmail(_resetEmailController.text);
    if (emailError != null) { _showMessage(emailError); return; }
    FocusScope.of(context).unfocus();
    final success = await auth.sendLocalPasswordResetCode(email: _resetEmailController.text);
    if (!success || !mounted) return;
    _startCooldown(false);
    _showMessage('重置验证码已发送到邮箱');
  }

  Future<void> _submitReset(AuthProvider auth) async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    if (_resetNewPasswordController.text != _resetConfirmPasswordController.text) {
      _showMessage('两次新密码输入不一致');
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await auth.resetLocalPassword(
      email: _resetEmailController.text,
      code: _resetCodeController.text,
      newPassword: _resetNewPasswordController.text,
    );
    if (!success || !mounted) return;
    _loginEmailController.text = _resetEmailController.text.trim();
    _loginPasswordController.clear();
    _resetCodeController.clear();
    _resetNewPasswordController.clear();
    _resetConfirmPasswordController.clear();
    _openEmailFlow(initialView: _LocalAuthView.login);
    _showMessage('密码已重置，请重新登录');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EdgeSwipeBackContainer(
      onBack: () => _resetToHome(context),
      child: Scaffold(
        body: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final authBusy = auth.isLoggingIn || auth.isLocalAuthBusy;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xxl, Spacing.lg, Spacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(RadiusTokens.card),
                        ),
                        child: Icon(
                          Icons.public_rounded,
                          size: 44,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Center(
                      child: Text(
                        'Globi',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Center(
                      child: Text(
                        '家属登录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: MinimalColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    if (auth.errorMessage != null) ...[
                      GlobiErrorBanner(
                        message: auth.errorMessage!,
                        onDismiss: auth.clearError,
                      ),
                      const SizedBox(height: Spacing.lg),
                    ],
                    if (_stage == _LoginStage.methodSelection)
                      _buildMethodSelection(context, auth, authBusy)
                    else
                      _buildLocalAuthCard(context, auth, authBusy),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocalAuthCard(BuildContext context, AuthProvider auth, bool authBusy) {
    final theme = Theme.of(context);
    final showsPrimarySwitch =
        _view == _LocalAuthView.login || _view == _LocalAuthView.register;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: authBusy ? null : _handleEmailFlowBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: '返回',
            ),
            Expanded(
              child: Text(
                _view == _LocalAuthView.verifyEmail
                    ? '验证邮箱'
                    : _view == _LocalAuthView.resetPassword
                    ? '重置密码'
                    : '使用邮箱登录',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        if (showsPrimarySwitch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_LocalAuthView>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                ),
                segments: const [
                  ButtonSegment<_LocalAuthView>(
                    value: _LocalAuthView.login,
                    label: Center(child: Text('登录')),
                  ),
                  ButtonSegment<_LocalAuthView>(
                    value: _LocalAuthView.register,
                    label: Center(child: Text('注册')),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: authBusy
                    ? null
                    : (selection) => _setView(selection.first),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Text(
              _view == _LocalAuthView.verifyEmail
                  ? '请输入邮箱收到的验证码完成验证。'
                  : '通过邮箱验证码重置新密码。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: Spacing.xl),
        Container(
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: BorderTokens.thin,
            ),
          ),
          child: switch (_view) {
            _LocalAuthView.login => _buildLoginForm(context, auth),
            _LocalAuthView.register => _buildRegisterForm(context, auth),
            _LocalAuthView.verifyEmail => _buildVerifyForm(context, auth),
            _LocalAuthView.resetPassword => _buildResetForm(context, auth),
          },
        ),
      ],
    );
  }

  Widget _buildMethodSelection(BuildContext context, AuthProvider auth, bool authBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLoginMethodButton(
          context,
          title: '使用邮箱登陆',
          iconAsset: 'assets/icons_login/email.svg',
          onTap: authBusy ? null : () => _openEmailFlow(),
        ),
        _buildLoginMethodButton(
          context,
          title: auth.isLoggingIn ? '请使用浏览器验证' : '使用 GitHub 登陆',
          iconAsset: 'assets/icons_login/email.svg',
          icon: Icons.code_rounded,
          onTap: authBusy && !auth.isLoggingIn ? null : auth.startGithubLogin,
          isLoading: auth.isLoggingIn,
          onCancel: auth.isLoggingIn ? auth.cancelGithubLogin : null,
        ),
      ],
    );
  }

  Widget _buildLoginMethodButton(
    BuildContext context, {
    required String title,
    required String iconAsset,
    IconData? icon,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isLoading = false,
    VoidCallback? onCancel,
  }) {
    final theme = Theme.of(context);
    final resolvedBackground = backgroundColor ?? theme.colorScheme.surface;
    final resolvedForeground = foregroundColor ?? MinimalColors.textPrimary;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.soft),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: BorderTokens.thin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: resolvedForeground.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(RadiusTokens.crisp),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: resolvedForeground,
                        ),
                      )
                    : icon != null
                        ? Icon(icon, size: 22, color: resolvedForeground)
                        : SvgPicture.asset(
                            iconAsset,
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              resolvedForeground,
                              BlendMode.srcIn,
                            ),
                          ),
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading && onCancel != null)
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close_rounded, size: 18, color: resolvedForeground),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: MinimalColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider auth) {
    final busy = auth.isLocalAuthActionInProgress(LocalAuthAction.login);

    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('local-login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailController,
            decoration: const InputDecoration(hintText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: _validateEmail,
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _loginPasswordController,
            decoration: const InputDecoration(hintText: '密码'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            validator: (value) => _validatePassword(value, label: '密码'),
            onFieldSubmitted: (_) => _submitLocalLogin(auth),
          ),
          const SizedBox(height: Spacing.lg),
          GlobiButton(
            label: '邮箱登录',
            icon: Icons.login_rounded,
            isLoading: busy,
            onPressed: () => _submitLocalLogin(auth),
          ),
          const SizedBox(height: Spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.isLocalAuthBusy
                  ? null
                  : () {
                      _resetEmailController.text = _loginEmailController.text.trim();
                      _setView(_LocalAuthView.resetPassword);
                    },
              child: const Text('忘记密码'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context, AuthProvider auth) {
    final busy = auth.isLocalAuthActionInProgress(LocalAuthAction.register);

    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('local-register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _registerEmailController,
            decoration: const InputDecoration(hintText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _registerPasswordController,
            decoration: const InputDecoration(hintText: '密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '密码'),
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _registerConfirmPasswordController,
            decoration: const InputDecoration(hintText: '确认密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '确认密码'),
            onFieldSubmitted: (_) => _submitRegister(auth),
          ),
          const SizedBox(height: Spacing.lg),
          GlobiButton(
            label: '注册并发送验证码',
            icon: Icons.mark_email_read_outlined,
            isLoading: busy,
            onPressed: () => _submitRegister(auth),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyForm(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    final verifyBusy = auth.isLocalAuthActionInProgress(LocalAuthAction.verifyEmail);
    final resendBusy = auth.isLocalAuthActionInProgress(LocalAuthAction.resendVerification);

    return Form(
      key: _verifyFormKey,
      child: Column(
        key: const ValueKey('local-verify'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '验证码会发送到邮箱，请输入 6 位数字验证码完成验证。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: MinimalColors.textSecondary,
            ),
          ),
          if (_verificationCodeTtlSeconds != null) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              '验证码有效期约 ${(_verificationCodeTtlSeconds! / 60).ceil()} 分钟',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _verifyEmailController,
            decoration: const InputDecoration(hintText: '邮箱'),
            enabled: false,
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _verifyCodeController,
            decoration: const InputDecoration(hintText: '验证码'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _validateCode,
            onFieldSubmitted: (_) => _submitVerify(auth),
          ),
          const SizedBox(height: Spacing.lg),
          GlobiButton(
            label: '完成验证',
            icon: Icons.verified_rounded,
            isLoading: verifyBusy,
            onPressed: () => _submitVerify(auth),
          ),
          const SizedBox(height: Spacing.sm),
          GlobiButton(
            label: _verificationCooldownRemaining > 0
                ? '重新发送 ${_verificationCooldownRemaining}s'
                : '重新发送验证码',
            icon: Icons.refresh_rounded,
            isOutlined: true,
            isDisabled: resendBusy || _verificationCooldownRemaining > 0,
            onPressed: () => _resendVerification(auth),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm(BuildContext context, AuthProvider auth) {
    final sendBusy = auth.isLocalAuthActionInProgress(LocalAuthAction.forgotPassword);
    final resetBusy = auth.isLocalAuthActionInProgress(LocalAuthAction.resetPassword);

    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('local-reset'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '先发送验证码，再输入验证码和新密码完成重置。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MinimalColors.textSecondary,
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _resetEmailController,
            decoration: const InputDecoration(hintText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _resetCodeController,
            decoration: const InputDecoration(hintText: '验证码'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _validateCode,
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _resetNewPasswordController,
            decoration: const InputDecoration(hintText: '新密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '新密码'),
          ),
          const SizedBox(height: Spacing.md),
          TextFormField(
            controller: _resetConfirmPasswordController,
            decoration: const InputDecoration(hintText: '确认新密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '确认新密码'),
            onFieldSubmitted: (_) => _submitReset(auth),
          ),
          const SizedBox(height: Spacing.lg),
          GlobiButton(
            label: _resetCooldownRemaining > 0
                ? '发送验证码 ${_resetCooldownRemaining}s'
                : '发送重置验证码',
            icon: Icons.email_outlined,
            isOutlined: true,
            isDisabled: sendBusy || _resetCooldownRemaining > 0,
            onPressed: () => _sendResetCode(auth),
          ),
          const SizedBox(height: Spacing.sm),
          GlobiButton(
            label: '重置密码',
            icon: Icons.lock_reset_rounded,
            isLoading: resetBusy,
            onPressed: () => _submitReset(auth),
          ),
        ],
      ),
    );
  }
}
