import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';

import '../config/design_tokens.dart';
import '../providers/app_mode_provider.dart';
import '../providers/blind_mode_provider.dart';
import '../widgets/edge_swipe_back_container.dart';

class BlindLinkScreen extends StatefulWidget {
  const BlindLinkScreen({super.key});

  @override
  State<BlindLinkScreen> createState() => _BlindLinkScreenState();
}

class _BlindLinkScreenState extends State<BlindLinkScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _authorizationCodeController =
      TextEditingController();

  late final AnimationController _shakeController;
  bool _isError = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _authorizationCodeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    if (_authorizationCodeController.text.isEmpty && (_isError || _isSuccess)) {
      setState(() {
        _isError = false;
        _isSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _authorizationCodeController.removeListener(_onCodeChanged);
    _shakeController.dispose();
    _authorizationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final blindMode = context.read<BlindModeProvider>();
    if (blindMode.isLinking) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isError = false;
      _isSuccess = false;
    });

    await blindMode.redeemBlindLinkCode(
      authorizationCode: _authorizationCodeController.text,
      deviceLabel: '',
    );

    if (mounted) {
      if (blindMode.errorMessage != null) {
        setState(() {
          _isError = true;
          _isSuccess = false;
        });
        _shakeController.forward(from: 0);
      } else {
        setState(() {
          _isSuccess = true;
          _isError = false;
        });
      }
    }
  }

  Future<void> _resetToHome() async {
    FocusScope.of(context).unfocus();
    await context.read<AppModeProvider>().resetMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EdgeSwipeBackContainer(
      onBack: _resetToHome,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.xxl,
            ),
            child: Consumer<BlindModeProvider>(
              builder: (context, blindMode, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '请输入授权码',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.02,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Spacing.xxl),
                            AnimatedBuilder(
                              animation: _shakeController,
                              builder: (context, child) {
                                final sineValue = math.sin(
                                  _shakeController.value * math.pi * 4,
                                );
                                return Transform.translate(
                                  offset: Offset(sineValue * 8.0, 0),
                                  child: child,
                                );
                              },
                              child: Center(
                                child: Pinput(
                                  length: 8,
                                  controller: _authorizationCodeController,
                                  defaultPinTheme: PinTheme(
                                    width: 36,
                                    height: 52,
                                    textStyle: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(RadiusTokens.soft),
                                      border: Border.all(
                                        color: theme.colorScheme.outline,
                                        width: BorderTokens.thin,
                                      ),
                                    ),
                                  ),
                                  focusedPinTheme: PinTheme(
                                    width: 38,
                                    height: 54,
                                    textStyle: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(RadiusTokens.soft),
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  separatorBuilder: (index) {
                                    if (index == 3) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Spacing.xs,
                                        ),
                                        child: Text(
                                          '-',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500,
                                            color: MinimalColors.textSecondary,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox(width: Spacing.xs);
                                  },
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  keyboardType: TextInputType.visiblePassword,
                                  onCompleted: (_) => _submit(),
                                ),
                              ),
                            ),
                            const SizedBox(height: Spacing.xxl),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: blindMode.isLinking || _isSuccess
                                    ? null
                                    : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: (_isError || _isSuccess)
                                      ? MinimalColors.accentRedText
                                      : null,
                                  disabledBackgroundColor: _isSuccess
                                      ? MinimalColors.accentRedText
                                      : null,
                                  disabledForegroundColor: _isSuccess
                                      ? MinimalColors.textInverse
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      RadiusTokens.crisp,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  blindMode.isLinking
                                      ? '绑定中'
                                      : (_isError
                                            ? '授权码错误'
                                            : (_isSuccess ? '授权码正确' : '确定')),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        '授权码由家属账号生成',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: MinimalColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
