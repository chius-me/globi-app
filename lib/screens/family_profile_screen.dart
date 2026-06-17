import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/globi_button.dart';
import '../widgets/globi_error_banner.dart';

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _didInitializeControllers = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeControllers) return;
    final auth = context.read<AuthProvider>();
    final bootstrap = auth.familyProfileBootstrap;
    _emailController.text = bootstrap?.initialEmail ?? auth.user?.email ?? '';
    _phoneController.text = bootstrap?.initialPhone ?? '';
    _nameController.text =
        bootstrap?.initialName ?? auth.user?.displayName ?? '';
    _didInitializeControllers = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().saveFamilyProfile(
      email: _emailController.text,
      phone: _phoneController.text,
      name: _nameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('完善家属资料')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final errorMessage = auth.familyProfileErrorMessage;

              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.lg),
                    child: Text(
                      '首次登录需要补充联系人资料，保存后才能继续绑定盲人用户。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MinimalColors.textSecondary,
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    GlobiErrorBanner(
                      message: errorMessage,
                      onDismiss: auth.clearError,
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (auth.familyProfileStatus == FamilyProfileStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: OutlinedButton.icon(
                          onPressed: auth.refreshFamilyProfileBootstrap,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('重新加载资料状态'),
                        ),
                      ),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '邮箱'),
                  ),
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '电话'),
                  ),
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: '姓名'),
                  ),
                  const SizedBox(height: Spacing.xl),
                  GlobiButton(
                    label: auth.isSavingFamilyProfile ? '保存中...' : '保存并进入家属主页',
                    isLoading: auth.isSavingFamilyProfile,
                    onPressed: _submit,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
