import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/guclyft_logo.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final result = await AuthService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;

    if (result.role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminHomeScreen(name: result.name)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(name: result.name, role: result.role)),
      );
    }
  } catch (e) {
    setState(() {
      _error = e.toString().replaceAll("Exception: ", "");
    });
  } finally {
    setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  const GuclyftLogo(),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Log In"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text("Don't have an account? Sign up",
                        style: TextStyle(color: AppColors.blue)),
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