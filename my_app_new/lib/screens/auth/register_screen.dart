import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Icon(
          Icons.person_add_alt_1,
          size: 80,
          color: Colors.blue,
        ),
        SizedBox(height: 16),
        Text(
          "Create Account",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Create an account to start playing",
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: "Username",
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
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

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: "Confirm Password",
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off
                : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () async {
          try {
            await _authService.signUp(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

            if (!mounted) return;
            
            final user = FirebaseAuth.instance.currentUser!;
            await _userService.createUser(user, _usernameController.text);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Register successfully!"),
              ),
            );

            Navigator.pop(context);
          } on FirebaseAuthException catch (e) {
            String message;

            switch (e.code) {
              case "email-already-in-use":
                message = "Email already exists.";
                break;

              case "weak-password":
                message = "Password must be at least 6 characters.";
                break;

              case "invalid-email":
                message = "Invalid email.";
                break;

              default:
                message = e.message ?? "Register failed.";
            }

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
              ),
            );
          }
        },
        child: const Text(
          "REGISTER",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Login"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTitle(),

                const SizedBox(height: 40),

                _buildUsernameField(),

                const SizedBox(height: 20),

                _buildEmailField(),

                const SizedBox(height: 20),

                _buildPasswordField(),

                const SizedBox(height: 20),

                _buildConfirmPasswordField(),

                const SizedBox(height: 30),

                _buildRegisterButton(),

                const SizedBox(height: 20),

                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}