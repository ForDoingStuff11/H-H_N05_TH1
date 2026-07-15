import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _userService.setStatus(uid, "online");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login successful!"),
        ),
      );

    } on FirebaseAuthException catch (e) {

      String message;

      switch (e.code) {
        case "invalid-credential":
          message = "Wrong email or password.";
          break;

        case "user-not-found":
          message = "User not found.";
          break;

        case "wrong-password":
          message = "Wrong password.";
          break;

        case "invalid-email":
          message = "Invalid email.";
          break;

        default:
          message = e.message ?? "Login failed.";
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          
        ),
      );
    }
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Icon(
          Icons.grid_on_rounded,
          size: 80,
          color: Colors.blue,
        ),
        SizedBox(height: 16),
        Text(
          "Online Caro",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Sign in to continue",
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: "Email",
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: "Password",
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off
                : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
      onPressed: () async {
        await _login();
      },
        child: const Text(
          "LOGIN",
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?"),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            );
          },
          child: const Text("Register"),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTitle(),

                const SizedBox(height: 40),

                _buildEmailField(),

                const SizedBox(height: 20),

                _buildPasswordField(),

                const SizedBox(height: 30),

                _buildLoginButton(),

                const SizedBox(height: 20),

                _buildRegisterButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}