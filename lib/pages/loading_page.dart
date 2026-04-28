import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    verificarPerfil();
  }

  Future<void> verificarPerfil() async {
    final session = supabase.auth.currentSession;

    if (session == null) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    try {
      final userId = session.user.id;

      final profile = await supabase
          .from('profiles')
          .select('tipo')
          .eq('id', userId)
          .single();

      final tipo = (profile['tipo'] ?? '').toString();

      if (!mounted) return;

      if (tipo == 'admin') {
        context.go('/dashboard');
      } else if (tipo == 'cliente') {
        context.go('/cliente-dashboard');
      } else if (tipo == 'colaborador') {
        context.go('/colaborador-dashboard');
      } else {
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}