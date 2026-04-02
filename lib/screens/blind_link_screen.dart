import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/blind_mode_provider.dart';
import '../widgets/edge_swipe_back_container.dart';

class BlindLinkScreen extends StatefulWidget {
  const BlindLinkScreen({super.key});

  @override
  State<BlindLinkScreen> createState() => _BlindLinkScreenState();
}

class _BlindLinkScreenState extends State<BlindLinkScreen> {
  final TextEditingController _authorizationCodeController =
      TextEditingController();

  @override
  void dispose() {
    _authorizationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await context.read<BlindModeProvider>().redeemBlindLinkCode(
      authorizationCode: _authorizationCodeController.text,
      deviceLabel: '',
    );
  }

  Future<void> _resetToHome() async {
    FocusScope.of(context).unfocus();
    await context.read<AppModeProvider>().resetMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return EdgeSwipeBackContainer(
      onBack: _resetToHome,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                            if (blindMode.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Text(
                                  blindMode.errorMessage!,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            TextField(
                              controller: _authorizationCodeController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: '请输入授权码',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 80,
                              child: FilledButton(
                                onPressed: blindMode.isLinking ? null : _submit,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  blindMode.isLinking ? '绑定中' : '确定',
                                  style: const TextStyle(
                                    fontSize: 28,
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '授权码由家属账号生成',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
