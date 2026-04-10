import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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
    if (value == null || value.isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次新密码输入不一致')));
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await auth.changeLocalPassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!success || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('密码修改成功')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final busy = auth.isLocalAuthActionInProgress(
          LocalAuthAction.changePassword,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('修改密码')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (auth.errorMessage != null) ...[
                    Material(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          auth.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '当前入口只对本地邮箱密码账号开放。Authentik 登录账号请到单点登录系统修改密码。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: const InputDecoration(labelText: '新密码'),
                          obscureText: true,
                          validator: (value) => _validatePassword(value, '新密码'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(labelText: '确认新密码'),
                          obscureText: true,
                          validator: (value) =>
                              _validatePassword(value, '确认新密码'),
                          onFieldSubmitted: (_) => _submit(auth),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _submit(auth),
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_reset_rounded),
                          label: const Text('保存新密码'),
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
