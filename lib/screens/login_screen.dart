import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/edge_swipe_back_container.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _resetToHome(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await context.read<AppModeProvider>().resetMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return EdgeSwipeBackContainer(
      onBack: () => _resetToHome(context),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        child: Icon(
                          Icons.public,
                          size: 66,
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
                    const Spacer(flex: 2),
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
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                color: colorScheme.onErrorContainer,
                                onPressed: auth.clearError,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Material(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: auth.isLoggingIn ? null : auth.startLogin,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.1),
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
                                        Icons.login,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.isLoggingIn
                                          ? '正在跳转...'
                                          : '使用Authentik登陆',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '将通过浏览器完成安全登录',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onPrimaryContainer
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
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
