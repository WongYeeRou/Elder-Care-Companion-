import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'user_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _tryLogin() {
    if (!_formKey.currentState!.validate()) return;
    if (_email.text.trim() == 'user@example.com' && _password.text == '123456') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful')));
      Navigator.pushReplacementNamed(context, UserHomeShell.route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AppShell(
      titleTop: 'ElderCare',
      titleBottom: 'Companion',
      subtitle: 'Login to your account',
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _tryLogin, child: const Text('Login')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, ForgotPasswordPage.route),
                  child: const Text('Forgot password?'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                    children: [
                      const TextSpan(text: "Doesn't have an account? "),
                      TextSpan(
                        text: 'Register here',
                        style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.pushNamed(context, RegisterRolePage.route),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* Simple page shell used by this file */
class _AppShell extends StatelessWidget {
  final String titleTop;
  final String titleBottom;
  final String? subtitle;
  final List<Widget> children;
  const _AppShell({required this.titleTop, required this.titleBottom, this.subtitle, required this.children});

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
                  Center(
                    child: Opacity(opacity: .75, child: Text('Terms of use. Privacy Policy', style: Theme.of(context).textTheme.bodySmall)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
