import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth = AuthService();
  final email = TextEditingController();
  final pass = TextEditingController();

  Future<void> login() async {
    await auth.login(email.text, pass.text);
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Delta Quest IT', style: TextStyle(fontSize: 24)),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: login, child: const Text('Entrar')),
            ],
          ),
        ),
      ),
    );
  }
}
