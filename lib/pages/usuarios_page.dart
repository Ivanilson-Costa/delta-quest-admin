import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final supabase = Supabase.instance.client;
  final _profileService = ProfileService();
  final _searchController = TextEditingController();


Future<void> novoUsuario() async {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  String tipo = 'colaborador';
  bool salvando = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> salvar() async {
            final nome = nomeController.text.trim();
            final email = emailController.text.trim();
            final senha = senhaController.text.trim();

            if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preencha nome, e-mail e senha.'),
                ),
              );
              return;
            }

            setModalState(() => salvando = true);

            try {
              final response = await supabase.functions.invoke(
                'hyper-function',
                body: {
                  'nome': nome,
                  'email': email,
                  'password': senha,
                  'tipo': tipo,
                },
              );

              final data = response.data;

              if (data is Map && data['error'] != null) {
                throw Exception(data['error']);
              }

              if (context.mounted) {
                Navigator.pop(context);
              }

              await carregarTudo();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuário criado com sucesso.'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao criar usuário: $e')),
                );
              }
            } finally {
              setModalState(() => salvando = false);
            }
          }

          return AlertDialog(
            title: const Text('Novo usuário'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha temporária',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: 'cliente',
                        child: Text('Cliente'),
                      ),
                      DropdownMenuItem(
                        value: 'colaborador',
                        child: Text('Colaborador'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => tipo = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: salvando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: salvando ? null : salvar,
                child: salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar usuário'),
              ),
            ],
          );
        },
      );
    },
  );

  nomeController.dispose();
  emailController.dispose();
  senhaController.dispose();
}


  bool loading = true;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> usuarios = [];

  String abaSelecionada = 'todos';

  @override
  void initState() {
    super.initState();
    carregarTudo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> carregarTudo() async {
    setState(() => loading = true);

    try {
      final perfil = await _profileService.getProfile();

      final data = await supabase
          .from('profiles')
          .select('id, nome, tipo, ativo, created_at')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        profile = perfil;
        usuarios = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar usuários: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get usuariosFiltrados {
    final busca = _searchController.text.trim().toLowerCase();

    return usuarios.where((u) {
      final nome = (u['nome'] ?? '').toString().toLowerCase();
      final tipo = (u['tipo'] ?? '').toString();
      final ativo = u['ativo'] == true;

      final bateBusca = busca.isEmpty || nome.contains(busca);

      final bateAba = switch (abaSelecionada) {
        'admins' => tipo == 'admin',
        'clientes' => tipo == 'cliente',
        'colaboradores' => tipo == 'colaborador',
        'inativos' => !ativo,
        _ => true,
      };

      return bateBusca && bateAba;
    }).toList();
  }

  int get totalUsuarios => usuarios.length;
  int get totalAdmins => usuarios.where((u) => u['tipo'] == 'admin').length;
  int get totalClientes => usuarios.where((u) => u['tipo'] == 'cliente').length;
  int get totalColaboradores =>
      usuarios.where((u) => u['tipo'] == 'colaborador').length;
  int get totalInativos => usuarios.where((u) => u['ativo'] == false).length;

  Future<void> editarUsuario(Map<String, dynamic> usuario) async {
    final nomeController = TextEditingController(
      text: usuario['nome']?.toString() ?? '',
    );

    String tipo = usuario['tipo']?.toString() ?? 'colaborador';
    bool ativo = usuario['ativo'] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar usuário'),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'cliente',
                          child: Text('Cliente'),
                        ),
                        DropdownMenuItem(
                          value: 'colaborador',
                          child: Text('Colaborador'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => tipo = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usuário ativo'),
                      value: ativo,
                      onChanged: (value) {
                        setModalState(() => ativo = value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabase.from('profiles').update({
                  'nome': nomeController.text.trim(),
                  'tipo': tipo,
                  'ativo': ativo,
                }).eq('id', usuario['id']);

                if (context.mounted) {
                  Navigator.pop(context);
                }

                await carregarTudo();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeController.dispose();
  }

  Future<void> alternarStatus(Map<String, dynamic> usuario) async {
    final ativoAtual = usuario['ativo'] == true;

    await supabase.from('profiles').update({
      'ativo': !ativoAtual,
    }).eq('id', usuario['id']);

    await carregarTudo();
  }

  Future<void> excluirUsuario(Map<String, dynamic> usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text(
          'Deseja realmente excluir "${usuario['nome'] ?? ''}"?\n\n'
          'O usuário será ocultado do sistema, mas não será apagado do Auth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await supabase.from('profiles').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'ativo': false,
    }).eq('id', usuario['id']);

    await carregarTudo();
  }

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? 'Usuário').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    return AdminShell(
      title: 'Usuários',
      userName: nome,
      userType: tipo,
      selectedIndex: 1,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ResumoCard(
                      titulo: 'Total',
                      valor: totalUsuarios.toString(),
                      icone: Icons.people_alt_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Admins',
                      valor: totalAdmins.toString(),
                      icone: Icons.admin_panel_settings_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Clientes',
                      valor: totalClientes.toString(),
                      icone: Icons.business_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Colaboradores',
                      valor: totalColaboradores.toString(),
                      icone: Icons.badge_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Inativos',
                      valor: totalInativos.toString(),
                      icone: Icons.person_off_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Gerenciamento de usuários',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                         ElevatedButton.icon(
                            onPressed: novoUsuario,
                            icon: const Icon(Icons.add),
                            label: const Text('Novo usuário'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar por nome',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FiltroChip(
                              label: 'Todos',
                              selected: abaSelecionada == 'todos',
                              onTap: () =>
                                  setState(() => abaSelecionada = 'todos'),
                            ),
                            _FiltroChip(
                              label: 'Admins',
                              selected: abaSelecionada == 'admins',
                              onTap: () =>
                                  setState(() => abaSelecionada = 'admins'),
                            ),
                            _FiltroChip(
                              label: 'Clientes',
                              selected: abaSelecionada == 'clientes',
                              onTap: () =>
                                  setState(() => abaSelecionada = 'clientes'),
                            ),
                            _FiltroChip(
                              label: 'Colaboradores',
                              selected: abaSelecionada == 'colaboradores',
                              onTap: () => setState(
                                () => abaSelecionada = 'colaboradores',
                              ),
                            ),
                            _FiltroChip(
                              label: 'Inativos',
                              selected: abaSelecionada == 'inativos',
                              onTap: () =>
                                  setState(() => abaSelecionada = 'inativos'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (usuariosFiltrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhum usuário encontrado.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nome')),
                              DataColumn(label: Text('Tipo')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: usuariosFiltrados.map((usuario) {
                              final ativo = usuario['ativo'] == true;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(usuario['nome']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    _TipoBadge(
                                      tipo: usuario['tipo']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    _StatusBadge(ativo: ativo),
                                  ),
                                  DataCell(
                                    SelectableText(
                                      usuario['id']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar',
                                          icon: const Icon(Icons.edit_rounded),
                                          onPressed: () =>
                                              editarUsuario(usuario),
                                        ),
                                        IconButton(
                                          tooltip: ativo
                                              ? 'Desativar'
                                              : 'Ativar',
                                          icon: Icon(
                                            ativo
                                                ? Icons.toggle_on_rounded
                                                : Icons.toggle_off_rounded,
                                          ),
                                          onPressed: () =>
                                              alternarStatus(usuario),
                                        ),
                                        IconButton(
                                          tooltip: 'Excluir',
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          onPressed: () =>
                                              excluirUsuario(usuario),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _ResumoCard({
    required this.titulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icone,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  final String tipo;

  const _TipoBadge({required this.tipo});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;
    String label;

    switch (tipo) {
      case 'admin':
        background = const Color(0xFFEDE9FE);
        textColor = const Color(0xFF5B21B6);
        label = 'admin';
        break;
      case 'cliente':
        background = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        label = 'cliente';
        break;
      case 'colaborador':
        background = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        label = 'colaborador';
        break;
      default:
        background = const Color(0xFFE5E7EB);
        textColor = const Color(0xFF374151);
        label = tipo.isEmpty ? '-' : tipo;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool ativo;

  const _StatusBadge({required this.ativo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ativo ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? 'ativo' : 'inativo',
        style: TextStyle(
          color: ativo ? const Color(0xFF047857) : const Color(0xFF991B1B),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}