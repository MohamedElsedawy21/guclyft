import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/guclyft_logo.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, newPassword, done }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _resetToken;
  bool _loading = false;
  String? _error;

  Future<void> _sendCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = "Please enter your email");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.forgotPassword(_emailController.text.trim());
      setState(() => _step = _Step.code);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = "Please enter the code");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthService.verifyResetCode(
        _emailController.text.trim(),
        _codeController.text.trim(),
      );
      setState(() {
        _resetToken = token;
        _step = _Step.newPassword;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty) {
      setState(() => _error = "Please enter a new password");
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = "Passwords don't match");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.resetPassword(_resetToken!, _newPasswordController.text);
      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const GuclyftLogo(size: 70),
                  const SizedBox(height: 32),
                  _buildStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.email:
        return _buildEmailStep();
      case _Step.code:
        return _buildCodeStep();
      case _Step.newPassword:
        return _buildNewPasswordStep();
      case _Step.done:
        return _buildDoneStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        const Text("Enter your email and we'll send you a reset code.",
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendCode,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Send Code"),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        Text("Enter the 6-digit code sent to ${_emailController.text.trim()}",
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: "Reset Code", prefixIcon: Icon(Icons.pin_outlined)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _verifyCode,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Verify Code"),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text("Resend Code", style: TextStyle(color: AppColors.blue)),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        const Text("Set your new password.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New Password", prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_outline)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Reset Password"),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 16),
        const Text("Password reset successful!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Back to Login"),
          ),
        ),
      ],
    );
  }
}