import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/edge_swipe_back_container.dart';

enum _LocalAuthView { login, register, verifyEmail, resetPassword }

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
    _setView(_LocalAuthView.login, clearError: false);
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
    _setView(_LocalAuthView.login, clearError: false);
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
                    _buildLocalAuthCard(context, auth, authBusy),
                    const SizedBox(height: 16),
                    _buildOidcCard(context, auth, authBusy),
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

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '邮箱密码',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '支持注册、邮箱验证、登录，以及忘记密码后的重置。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (showsPrimarySwitch)
              SegmentedButton<_LocalAuthView>(
                segments: const [
                  ButtonSegment<_LocalAuthView>(
                    value: _LocalAuthView.login,
                    icon: Icon(Icons.mail_outline_rounded),
                    label: Text('登录'),
                  ),
                  ButtonSegment<_LocalAuthView>(
                    value: _LocalAuthView.register,
                    icon: Icon(Icons.person_add_alt_1_rounded),
                    label: Text('注册'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: authBusy
                    ? null
                    : (selection) {
                        final next = selection.first;
                        _setView(next);
                      },
              )
            else
              Row(
                children: [
                  IconButton(
                    onPressed: authBusy
                        ? null
                        : () => _setView(_LocalAuthView.login),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _view == _LocalAuthView.verifyEmail ? '验证邮箱' : '重置密码',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_view) {
                _LocalAuthView.login => _buildLoginForm(context, auth),
                _LocalAuthView.register => _buildRegisterForm(context, auth),
                _LocalAuthView.verifyEmail => _buildVerifyForm(context, auth),
                _LocalAuthView.resetPassword => _buildResetForm(context, auth),
              },
            ),
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
            decoration: const InputDecoration(labelText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPasswordController,
            decoration: const InputDecoration(labelText: '密码'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final busy = auth.isLocalAuthActionInProgress(LocalAuthAction.register);

    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('local-register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _registerEmailController,
            decoration: const InputDecoration(labelText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerPasswordController,
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '密码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerConfirmPasswordController,
            decoration: const InputDecoration(labelText: '确认密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '确认密码'),
            onFieldSubmitted: (_) => _submitRegister(auth),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '注册成功后会进入邮箱验证码页面，不会直接登录。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
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
            decoration: const InputDecoration(labelText: '邮箱'),
            enabled: false,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _verifyCodeController,
            decoration: const InputDecoration(labelText: '验证码'),
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
            decoration: const InputDecoration(labelText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resetCodeController,
            decoration: const InputDecoration(labelText: '验证码'),
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
            decoration: const InputDecoration(labelText: '新密码'),
            obscureText: true,
            validator: (value) => _validatePassword(value, label: '新密码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resetConfirmPasswordController,
            decoration: const InputDecoration(labelText: '确认新密码'),
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

  Widget _buildOidcCard(
    BuildContext context,
    AuthProvider auth,
    bool authBusy,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: authBusy ? null : auth.startOidcLogin,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: auth.isLoggingIn
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : Icon(
                        Icons.open_in_browser_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.isLoggingIn ? '正在跳转...' : '使用Authentik登陆',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '将通过浏览器完成安全登录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
