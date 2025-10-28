import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  static const route = '/forgot';
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset link sent to ${_email.text.trim()} (prototype)')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      titleTop: 'ElderCare',
      titleBottom: 'Companion',
      subtitle: 'Reset your password',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _sendReset, child: const Text('Send reset link')),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Return to Login')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Shell extends StatelessWidget {
  final String titleTop;
  final String titleBottom;
  final String? subtitle;
  final List<Widget> children;
  const _Shell({required this.titleTop, required this.titleBottom, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(titleTop, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.1), textAlign: TextAlign.center),
                  Text(titleBottom, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.1), textAlign: TextAlign.center),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(.7))),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                  const SizedBox(height: 16),
                  Center(child: Opacity(opacity: .75, child: Text('Terms of use. Privacy Policy', style: Theme.of(context).textTheme.bodySmall))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
