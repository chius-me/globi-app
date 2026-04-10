import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
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
    if (clearError) {
      context.read<AuthProvider>().clearError();
    }

    setState(() {
      _view = view;
    });
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入邮箱';
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(trimmed)) {
      return '请输入正确的邮箱';
    }

    return null;
  }

  String? _validatePassword(String? value, {required String label}) {
    if (value == null || value.isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入验证码';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return '请输入6位验证码';
    }

    return null;
  }

  void _startVerificationCooldown([int seconds = _resendCooldownSeconds]) {
    _verificationCooldownTimer?.cancel();
    setState(() {
      _verificationCooldownRemaining = seconds;
    });

    _verificationCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_verificationCooldownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _verificationCooldownRemaining = 0;
        });
        return;
      }

      setState(() {
        _verificationCooldownRemaining -= 1;
      });
    });
  }

  void _startResetCooldown([int seconds = _resendCooldownSeconds]) {
    _resetCooldownTimer?.cancel();
    setState(() {
      _resetCooldownRemaining = seconds;
    });

    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resetCooldownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _resetCooldownRemaining = 0;
        });
        return;
      }

      setState(() {
        _resetCooldownRemaining -= 1;
      });
    });
  }

  Future<void> _submitLocalLogin(AuthProvider auth) async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    await auth.loginWithLocalAccount(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );
  }

  Future<void> _submitRegister(AuthProvider auth) async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_registerPasswordController.text !=
        _registerConfirmPasswordController.text) {
      _showMessage('两次密码输入不一致');
      return;
    }

    FocusScope.of(context).unfocus();
    final result = await auth.registerLocalAccount(
      email: _registerEmailController.text,
      password: _registerPasswordController.text,
    );
    if (result == null || !mounted) {
      return;
    }

    _verifyEmailController.text = result.email;
    _verifyCodeController.clear();
    _loginEmailController.text = result.email;

    setState(() {
      _view = _LocalAuthView.verifyEmail;
      _verificationCodeTtlSeconds = result.codeTtlSeconds > 0
          ? result.codeTtlSeconds
          : null;
    });
    _startVerificationCooldown();

    final message = result.emailSent
        ? '验证码已发送到 ${result.email}'
        : '注册成功，请输入邮箱验证码';
    _showMessage(message);
  }

  Future<void> _submitVerify(AuthProvider auth) async {
    if (!(_verifyFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await auth.verifyLocalEmail(
      email: _verifyEmailController.text,
      code: _verifyCodeController.text,
    );
    if (!success || !mounted) {
      return;
    }

    _verifyCodeController.clear();
    _openEmailFlow(initialView: _LocalAuthView.login);
    _showMessage('邮箱验证完成，请使用邮箱密码登录');
  }

  Future<void> _resendVerification(AuthProvider auth) async {
    if (_verificationCooldownRemaining > 0) {
      return;
    }

    final emailError = _validateEmail(_verifyEmailController.text);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await auth.resendLocalVerificationCode(
      email: _verifyEmailController.text,
    );
    if (!success || !mounted) {
      return;
    }

    _startVerificationCooldown();
    _showMessage('验证码已重新发送');
  }

  Future<void> _sendResetCode(AuthProvider auth) async {
    final emailError = _validateEmail(_resetEmailController.text);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await auth.sendLocalPasswordResetCode(
      email: _resetEmailController.text,
    );
    if (!success || !mounted) {
      return;
    }

    _startResetCooldown();
    _showMessage('重置验证码已发送到邮箱');
  }

  Future<void> _submitReset(AuthProvider auth) async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_resetNewPasswordController.text !=
        _resetConfirmPasswordController.text) {
      _showMessage('两次新密码输入不一致');
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await auth.resetLocalPassword(
      email: _resetEmailController.text,
      code: _resetCodeController.text,
      newPassword: _resetNewPasswordController.text,
    );
    if (!success || !mounted) {
      return;
    }

    _loginEmailController.text = _resetEmailController.text.trim();
    _loginPasswordController.clear();
    _resetCodeController.clear();
    _resetNewPasswordController.clear();
    _resetConfirmPasswordController.clear();
    _openEmailFlow(initialView: _LocalAuthView.login);
    _showMessage('密码已重置，请重新登录');
  }

  String _cooldownLabel(int seconds) {
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return EdgeSwipeBackContainer(
      onBack: () => _resetToHome(context),
      child: Scaffold(
        body: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final authBusy = auth.isLoggingIn || auth.isLocalAuthBusy;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(36),
                        ),
                        child: Icon(
                          Icons.public,
                          size: 68,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Globi',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '家属登录',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (auth.errorMessage != null) ...[
                      Material(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: auth.clearError,
                                icon: const Icon(Icons.close),
                                color: colorScheme.onErrorContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildLocalAuthCard(
    BuildContext context,
    AuthProvider auth,
    bool authBusy,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showsPrimarySwitch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_LocalAuthView>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                    : (selection) {
                        final next = selection.first;
                        _setView(next);
                      },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _view == _LocalAuthView.verifyEmail
                  ? '请输入邮箱收到的验证码完成验证。'
                  : '通过邮箱验证码重置新密码。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_view) {
              _LocalAuthView.login => _buildLoginForm(context, auth),
              _LocalAuthView.register => _buildRegisterForm(context, auth),
              _LocalAuthView.verifyEmail => _buildVerifyForm(context, auth),
              _LocalAuthView.resetPassword => _buildResetForm(context, auth),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelection(
    BuildContext context,
    AuthProvider auth,
    bool authBusy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLoginMethodButton(
          context,
          title: '使用邮箱登陆',
          iconAsset: 'assets/icons_login/email.svg',
          onTap: authBusy ? null : () => _openEmailFlow(),
        ),
        const SizedBox(height: 16),
        _buildLoginMethodButton(
          context,
          title: '使用微信登陆',
          iconAsset: 'assets/icons_login/wechat.svg',
          backgroundColor: const Color(0xFFE9F9EC),
          foregroundColor: const Color(0xFF1F8F47),
          onTap: authBusy ? null : () => _showMessage('微信登录接口暂未接入'),
        ),
        const SizedBox(height: 16),
        _buildLoginMethodButton(
          context,
          title: auth.isLoggingIn ? '请使用浏览器验证' : '使用Authentik登陆',
          iconAsset: 'assets/icons_login/authentik.svg',
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          onTap: authBusy && !auth.isLoggingIn ? null : auth.startOidcLogin,
          isLoading: auth.isLoggingIn,
          onCancel: auth.isLoggingIn ? auth.cancelOidcLogin : null,
        ),
      ],
    );
  }

  Widget _buildLoginMethodButton(
    BuildContext context, {
    required String title,
    required String iconAsset,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isLoading = false,
    VoidCallback? onCancel,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedBackground =
        backgroundColor ?? colorScheme.surfaceContainerHighest;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;

    return Material(
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: resolvedForeground.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: resolvedForeground,
                        ),
                      )
                    : SvgPicture.asset(
                        iconAsset,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          resolvedForeground,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: resolvedForeground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isLoading && onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close_rounded, color: resolvedForeground),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                Icon(Icons.arrow_forward_rounded, color: resolvedForeground),
            ],
          ),
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
            decoration: InputDecoration(
              hintText: '邮箱',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPasswordController,
            decoration: InputDecoration(
              hintText: '密码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            validator: (value) => _validatePassword(value, label: '密码'),
            onFieldSubmitted: (_) => _submitLocalLogin(auth),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : () => _submitLocalLogin(auth),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text('邮箱登录'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.isLocalAuthBusy
                  ? null
                  : () {
                      _resetEmailController.text = _loginEmailController.text
                          .trim();
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
            decoration: InputDecoration(
              hintText: '邮箱',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerPasswordController,
            decoration: InputDecoration(
              hintText: '密码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '密码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerConfirmPasswordController,
            decoration: InputDecoration(
              hintText: '确认密码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '确认密码'),
            onFieldSubmitted: (_) => _submitRegister(auth),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : () => _submitRegister(auth),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_read_outlined),
            label: const Text('注册并发送验证码'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyForm(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final verifyBusy = auth.isLocalAuthActionInProgress(
      LocalAuthAction.verifyEmail,
    );
    final resendBusy = auth.isLocalAuthActionInProgress(
      LocalAuthAction.resendVerification,
    );

    return Form(
      key: _verifyFormKey,
      child: Column(
        key: const ValueKey('local-verify'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '验证码会发送到邮箱，请输入 6 位数字验证码完成验证。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (_verificationCodeTtlSeconds != null) ...[
            const SizedBox(height: 6),
            Text(
              '验证码有效期约 ${(_verificationCodeTtlSeconds! / 60).ceil()} 分钟',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _verifyEmailController,
            decoration: InputDecoration(
              hintText: '邮箱',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            enabled: false,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _verifyCodeController,
            decoration: InputDecoration(
              hintText: '验证码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _validateCode,
            onFieldSubmitted: (_) => _submitVerify(auth),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: verifyBusy ? null : () => _submitVerify(auth),
            icon: verifyBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_rounded),
            label: const Text('完成验证'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: resendBusy || _verificationCooldownRemaining > 0
                ? null
                : () => _resendVerification(auth),
            icon: resendBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              _verificationCooldownRemaining > 0
                  ? '重新发送 ${_cooldownLabel(_verificationCooldownRemaining)}'
                  : '重新发送验证码',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sendBusy = auth.isLocalAuthActionInProgress(
      LocalAuthAction.forgotPassword,
    );
    final resetBusy = auth.isLocalAuthActionInProgress(
      LocalAuthAction.resetPassword,
    );

    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('local-reset'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '先发送验证码，再输入验证码和新密码完成重置。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _resetEmailController,
            decoration: InputDecoration(
              hintText: '邮箱',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resetCodeController,
            decoration: InputDecoration(
              hintText: '验证码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _validateCode,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resetNewPasswordController,
            decoration: InputDecoration(
              hintText: '新密码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '新密码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resetConfirmPasswordController,
            decoration: InputDecoration(
              hintText: '确认新密码',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '确认新密码'),
            onFieldSubmitted: (_) => _submitReset(auth),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: sendBusy || _resetCooldownRemaining > 0
                ? null
                : () => _sendResetCode(auth),
            icon: sendBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.email_outlined),
            label: Text(
              _resetCooldownRemaining > 0
                  ? '发送验证码 ${_cooldownLabel(_resetCooldownRemaining)}'
                  : '发送重置验证码',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: resetBusy ? null : () => _submitReset(auth),
            icon: resetBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset_rounded),
            label: const Text('重置密码'),
          ),
        ],
      ),
    );
  }
}
