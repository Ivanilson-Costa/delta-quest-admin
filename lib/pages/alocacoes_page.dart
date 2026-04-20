import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/alocacoes_service.dart';
import '../services/pesquisas_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlocacoesPage extends StatefulWidget {
  const AlocacoesPage({super.key});

  @override
  State<AlocacoesPage> createState() => _AlocacoesPageState();
}

class _AlocacoesPageState extends State<AlocacoesPage> {
  final _service = AlocacoesService();
  final _profileService = ProfileService();
  final _searchController = TextEditingController();

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> alocacoes = [];
  bool loading = true;

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
      final lista = await _service.listarAlocacoes();

      if (!mounted) return;

      setState(() {
        profile = perfil;
        alocacoes = lista;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar alocações: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get alocacoesFiltradas {
    final q = _searchController.text.trim().toLowerCase();

    if (q.isEmpty) return alocacoes;

    return alocacoes.where((a) {
      final pesquisa =
          ((a['pesquisas']?['titulo']) ?? '').toString().toLowerCase();

      final colaborador = (((a['colaboradores']?['profiles']?['nome']) ??
              '')
          .toString()
          .toLowerCase());

      final email = (((a['colaboradores']?['profiles']?['email']) ?? '')
          .toString()
          .toLowerCase());

      return pesquisa.contains(q) ||
          colaborador.contains(q) ||
          email.contains(q);
    }).toList();
  }

  String formatarData(dynamic valor) {
    if (valor == null) return '-';
    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> abrirFormulario() async {
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlocacaoFormDialog(),
    );

    if (salvou == true) {
      await carregarTudo();
    }
  }

  Future<void> excluirAlocacao(Map<String, dynamic> alocacao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover alocação'),
        content: const Text(
          'Deseja realmente remover esta alocação?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _service.excluirAlocacao(alocacao['id'].toString());
    await carregarTudo();
  }

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? 'Usuário').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    return AdminShell(
      title: 'Alocações',
      userName: nome,
      userType: tipo,
      selectedIndex: 4,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alocação de colaboradores',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de alocações: ${alocacoes.length}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por pesquisa, colaborador ou e-mail',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: abrirFormulario,
                            icon: const Icon(Icons.add),
                            label: const Text('Nova alocação'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: carregarTudo,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Atualizar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (alocacoesFiltradas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhuma alocação encontrada.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF3F4F6),
                            ),
                            columns: const [
                              DataColumn(label: Text('Pesquisa')),
                              DataColumn(label: Text('Colaborador')),
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Ativo')),
                              DataColumn(label: Text('Criado em')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: alocacoesFiltradas.map((a) {
                              final pesquisa =
                                  ((a['pesquisas']?['titulo']) ?? '')
                                      .toString();
                              final colaborador =
                                  ((a['colaboradores']?['profiles']?['nome']) ??
                                          '')
                                      .toString();
                              final email =
                                  ((a['colaboradores']?['profiles']?['email']) ??
                                          '')
                                      .toString();
                              final ativo =
                                  (a['colaboradores']?['ativo'] ?? false) ==
                                      true;

                              return DataRow(
                                cells: [
                                  DataCell(Text(pesquisa)),
                                  DataCell(Text(colaborador)),
                                  DataCell(Text(email)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ativo
                                            ? const Color(0xFFD1FAE5)
                                            : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        ativo ? 'Sim' : 'Não',
                                        style: TextStyle(
                                          color: ativo
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF991B1B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(formatarData(a['created_at']))),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Remover',
                                      onPressed: () => excluirAlocacao(a),
                                      icon: const Icon(Icons.delete_outline),
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

class AlocacaoFormDialog extends StatefulWidget {
  const AlocacaoFormDialog({super.key});

  @override
  State<AlocacaoFormDialog> createState() => _AlocacaoFormDialogState();
}

class _AlocacaoFormDialogState extends State<AlocacaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = AlocacoesService();
  final _pesquisasService = PesquisasService();

  List<Map<String, dynamic>> pesquisas = [];
  List<Map<String, dynamic>> colaboradores = [];

  String? pesquisaId;
  String? colaboradorId;

  bool loading = true;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    try {
      final listaPesquisas = await _pesquisasService.listarPesquisas();

      final response = await Supabase.instance.client
          .from('colaboradores')
          .select('''
            id,
            ativo,
            profiles (
              id,
              nome,
              email
            )
          ''')
          .eq('ativo', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        pesquisas = listaPesquisas;
        colaboradores = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (pesquisaId == null || colaboradorId == null) return;

    setState(() => salvando = true);

    try {
      await _service.criarAlocacao(
        pesquisaId: pesquisaId!,
        colaboradorId: colaboradorId!,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar alocação: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nova alocação',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: pesquisaId,
                  decoration: const InputDecoration(
                    labelText: 'Pesquisa',
                    border: OutlineInputBorder(),
                  ),
                  items: pesquisas.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text((p['titulo'] ?? '').toString()),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => pesquisaId = value),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Selecione a pesquisa'
                          : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: colaboradorId,
                  decoration: const InputDecoration(
                    labelText: 'Colaborador',
                    border: OutlineInputBorder(),
                  ),
                  items: colaboradores.map((c) {
                    final nome =
                        ((c['profiles']?['nome']) ?? '').toString();
                    final email =
                        ((c['profiles']?['email']) ?? '').toString();

                    return DropdownMenuItem<String>(
                      value: c['id'].toString(),
                      child: Text('$nome${email.isNotEmpty ? ' - $email' : ''}'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => colaboradorId = value),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Selecione o colaborador'
                          : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          salvando ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: salvando ? null : salvar,
                      child: salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}