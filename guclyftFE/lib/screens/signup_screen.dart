import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/guclyft_logo.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _idController = TextEditingController();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _emailController = TextEditingController();
  final _facultyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signup(
        id: _idController.text.trim(),
        firstname: _firstController.text.trim(),
        lastname: _lastController.text.trim(),
        email: _emailController.text.trim(),
        faculty: _facultyController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup successful! Please log in.")),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController c, String label, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, prefixIcon: icon != null ? Icon(icon) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const GuclyftLogo(size: 70),
              const SizedBox(height: 28),
              _field(_idController, "University ID", icon: Icons.badge_outlined),
              _field(_firstController, "First Name"),
              _field(_lastController, "Last Name"),
              _field(_emailController, "Email", icon: Icons.email_outlined),
              _field(_facultyController, "Faculty"),
              _field(_usernameController, "Username", icon: Icons.person_outline),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Have an injury or disability? Add it later from your Account tab.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Sign Up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}