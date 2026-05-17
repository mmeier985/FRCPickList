import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../state/picklist_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _displayNameController = TextEditingController(text: 'Local Lead');
  final TextEditingController _emailController = TextEditingController(text: 'lead@example.org');
  final TextEditingController _teamOrgController = TextEditingController(text: 'team-4414');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _teamOrgController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PickListController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06111F), Color(0xFF0B1E35), Color(0xFF132A4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PickList',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in before you can view workspaces or start ranking teams.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Production accounts should already have a teamOrgId claim in Firebase.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _teamOrgController,
                          decoration: const InputDecoration(
                            labelText: 'Team org ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => controller.signIn(
                                      AuthCredentials(
                                        displayName: _displayNameController.text.trim().isEmpty
                                            ? 'FRC Member'
                                            : _displayNameController.text.trim(),
                                        email: _emailController.text.trim(),
                                        teamOrgId: _teamOrgController.text.trim(),
                                        password: _passwordController.text,
                                      ),
                                    ),
                            icon: controller.busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: Text(controller.busy ? 'Signing in...' : 'Sign in / create account'),
                          ),
                        ),
                        if (controller.error != null) ...[
                          const SizedBox(height: 12),
                          Text(controller.error!, style: const TextStyle(color: Colors.redAccent)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
