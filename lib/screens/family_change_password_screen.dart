import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/globi_button.dart';
import '../widgets/globi_error_banner.dart';

class FamilyChangePasswordScreen extends StatefulWidget {
  const FamilyChangePasswordScreen({super.key});

  @override
  State<FamilyChangePasswordScreen> createState() =>
      _FamilyChangePasswordScreenState();
}

class _FamilyChangePasswordScreenState
    extends State<FamilyChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value, String label) {
    if (value == null || value.isEmpty) return '请输入$label';
    return null;
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次新密码输入不一致')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await auth.changeLocalPassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!success || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码修改成功')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final busy = auth.isLocalAuthActionInProgress(
          LocalAuthAction.changePassword,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('修改密码')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (auth.errorMessage != null) ...[
                    GlobiErrorBanner(
                      message: auth.errorMessage!,
                      onDismiss: auth.clearError,
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],
                  Container(
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(RadiusTokens.soft),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: BorderTokens.thin,
                      ),
                    ),
                    child: Text(
                      '当前只支持本地邮箱密码账号修改密码。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: MinimalColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _oldPasswordController,
                          decoration: const InputDecoration(labelText: '旧密码'),
                          obscureText: true,
                          validator: (value) => _validatePassword(value, '旧密码'),
                        ),
                        const SizedBox(height: Spacing.md),
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: const InputDecoration(labelText: '新密码'),
                          obscureText: true,
                          validator: (value) => _validatePassword(value, '新密码'),
                        ),
                        const SizedBox(height: Spacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(labelText: '确认新密码'),
                          obscureText: true,
                          validator: (value) =>
                              _validatePassword(value, '确认新密码'),
                          onFieldSubmitted: (_) => _submit(auth),
                        ),
                        const SizedBox(height: Spacing.xl),
                        GlobiButton(
                          label: '保存新密码',
                          icon: Icons.lock_reset_rounded,
                          isLoading: busy,
                          onPressed: () => _submit(auth),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
