import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_shell.dart';

class MeuPerfilPage extends StatefulWidget {
  const MeuPerfilPage({super.key});

  @override
  State<MeuPerfilPage> createState() => _MeuPerfilPageState();
}

class _MeuPerfilPageState extends State<MeuPerfilPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    carregarPerfil();
  }

  Future<void> carregarPerfil() async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      setState(() => loading = false);
      return;
    }

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    setState(() {
      profile = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nome = profile?['nome'] ?? 'Usuário';
    final tipo = profile?['tipo'] ?? '';
    final email = supabase.auth.currentUser?.email ?? '';

    return AdminShell(
      title: 'Meu perfil',
      userName: nome,
      userType: tipo,
      selectedIndex: -1,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados do usuário',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoLinha(label: 'Nome', value: nome),
                    _InfoLinha(label: 'E-mail', value: email),
                    _InfoLinha(label: 'Tipo de usuário', value: tipo),
                    _InfoLinha(label: 'ID', value: profile?['id'] ?? ''),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLinha({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}