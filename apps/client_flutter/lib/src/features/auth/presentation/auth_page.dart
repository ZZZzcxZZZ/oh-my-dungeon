import 'package:flutter/material.dart';

import 'auth_controller.dart';

enum _AuthFormMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({required this.authController, super.key});

  final AuthController authController;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  _AuthFormMode _mode = _AuthFormMode.login;
  bool _submitting = false;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.authController.login(
        identifier: identifier,
        password: password,
      );
      _clearFormFields();
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _registerPasswordController.text;
    if (username.isEmpty || email.isEmpty || password.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.authController.register(
        username: username,
        email: email,
        password: password,
      );
      _clearFormFields();
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final controller = widget.authController;

        if (controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.isLoggedIn) {
          return _buildLoggedInView(context, controller);
        }

        return _buildAuthForm(context, controller);
      },
    );
  }

  Widget _buildLoggedInView(BuildContext context, AuthController controller) {
    final user = controller.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('账号')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已登录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person),
              title: Text(user.username),
              subtitle: Text(user.email),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _handleLogout,
              child: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _submitting = true);
    await widget.authController.logout();
    _clearFormFields();
    if (mounted) setState(() => _submitting = false);
  }

  void _clearFormFields() {
    _identifierController.clear();
    _passwordController.clear();
    _usernameController.clear();
    _emailController.clear();
    _registerPasswordController.clear();
  }

  Widget _buildAuthForm(BuildContext context, AuthController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(_mode == _AuthFormMode.login ? '登录' : '注册')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.error != null) ...[
                  Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_mode == _AuthFormMode.login) ...[
                  TextField(
                    controller: _identifierController,
                    decoration: const InputDecoration(labelText: '用户名或邮箱'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: '密码'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _handleLogin,
                    child: const Text('登录'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _mode = _AuthFormMode.register),
                    child: const Text('没有账号？注册'),
                  ),
                ] else ...[
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: '用户名'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: '邮箱'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _registerPasswordController,
                    decoration: const InputDecoration(labelText: '密码'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _handleRegister,
                    child: const Text('注册'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _mode = _AuthFormMode.login),
                    child: const Text('已有账号？登录'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
