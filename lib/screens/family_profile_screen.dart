import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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
    if (_didInitializeControllers) {
      return;
    }

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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('完善家属资料'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final errorMessage = auth.familyProfileErrorMessage;

              return ListView(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '首次登录需要补充联系人资料，保存后才能继续绑定盲人用户。',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (errorMessage != null) ...[
                    Material(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              errorMessage,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            if (auth.familyProfileStatus ==
                                FamilyProfileStatus.error) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: auth.refreshFamilyProfileBootstrap,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重新加载资料状态'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '电话',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '姓名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.isSavingFamilyProfile ? null : _submit,
                      child: Text(
                        auth.isSavingFamilyProfile ? '保存中...' : '保存并进入家属主页',
                      ),
                    ),
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
