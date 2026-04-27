import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_shell.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return AdminShell(
      title: 'Configurações',
      userName: user?.email ?? 'Usuário',
      userType: 'admin',
      selectedIndex: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfigCard(
            title: 'Sistema',
            children: [
              _ConfigItem(
                label: 'Nome do sistema',
                value: 'Delta Quest IT',
              ),
              _ConfigItem(
                label: 'Ambiente',
                value: 'Produção',
              ),
              _ConfigItem(
                label: 'Versão',
                value: '1.0.0',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ConfigCard(
            title: 'Conta',
            children: [
              _ConfigItem(
                label: 'E-mail logado',
                value: user?.email ?? '',
              ),
              _ConfigItem(
                label: 'ID do usuário',
                value: user?.id ?? '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ConfigCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  final String label;
  final String value;

  const _ConfigItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
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