import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/alocacoes_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class AlocacoesPage extends StatefulWidget {
  const AlocacoesPage({super.key});

  @override
  State<AlocacoesPage> createState() => _AlocacoesPageState();
}

class _AlocacoesPageState extends State<AlocacoesPage>
    with SingleTickerProviderStateMixin {
  final _service = AlocacoesService();
  final _profileService = ProfileService();
  final _searchController = TextEditingController();

  late final TabController _tabController;

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> alocacoes = [];
  bool loading = true;

  final List<String> abas = [
    'planejada',
    'em_andamento',
    'concluida',
    'cancelada',
    'todas',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: abas.length, vsync: this);
    _tabController.index = 1;
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    carregarTudo();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String get abaAtual => abas[_tabController.index];

  List<Map<String, dynamic>> get alocacoesFiltradas {
    final q = _searchController.text.trim().toLowerCase();

    return alocacoes.where((a) {
      final pesquisa =
          ((a['pesquisas']?['titulo']) ?? '').toString().toLowerCase();

      final colaborador =
          ((a['profiles']?['nome']) ?? '').toString().toLowerCase();

      final email = ((a['profiles']?['email']) ?? '').toString().toLowerCase();

      final status = ((a['pesquisas']?['status']) ?? '').toString();

      final bateBusca = q.isEmpty ||
          pesquisa.contains(q) ||
          colaborador.contains(q) ||
          email.contains(q);

      final bateAba = abaAtual == 'todas' || status == abaAtual;

      return bateBusca && bateAba;
    }).toList();
  }

  int totalPorStatus(String status) {
    if (status == 'todas') return alocacoes.length;

    return alocacoes.where((a) {
      final s = ((a['pesquisas']?['status']) ?? '').toString();
      return s == status;
    }).length;
  }

  String formatarData(dynamic valor) {
    if (valor == null) return '-';

    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return '-';

    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  String formatarStatus(String status) {
    switch (status) {
      case 'planejada':
        return 'Em planejamento';
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Concluídas';
      case 'pausada':
        return 'Pausada';
      case 'cancelada':
        return 'Canceladas';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  Widget statusChip(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'planejada':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'em_andamento':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'concluida':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'cancelada':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        formatarStatus(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
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
        content: const Text('Deseja realmente remover esta alocação?'),
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
                  'Distribua colaboradores para as pesquisas disponíveis.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ResumoCard(
                      titulo: 'Total',
                      valor: alocacoes.length.toString(),
                      icone: Icons.groups_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Em planejamento',
                      valor: totalPorStatus('planejada').toString(),
                      icone: Icons.event_note_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Em andamento',
                      valor: totalPorStatus('em_andamento').toString(),
                      icone: Icons.play_circle_outline_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Concluídas',
                      valor: totalPorStatus('concluida').toString(),
                      icone: Icons.check_circle_outline_rounded,
                    ),
                    _ResumoCard(
                      titulo: 'Canceladas',
                      valor: totalPorStatus('cancelada').toString(),
                      icone: Icons.cancel_outlined,
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
                            icon: const Icon(Icons.group_add_rounded),
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
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF2563EB),
                        unselectedLabelColor: const Color(0xFF6B7280),
                        indicatorColor: const Color(0xFF2563EB),
                        tabs: [
                          Tab(
                            text:
                                'Em planejamento (${totalPorStatus('planejada')})',
                          ),
                          Tab(
                            text:
                                'Em andamento (${totalPorStatus('em_andamento')})',
                          ),
                          Tab(
                            text: 'Concluídas (${totalPorStatus('concluida')})',
                          ),
                          Tab(
                            text: 'Canceladas (${totalPorStatus('cancelada')})',
                          ),
                          Tab(
                            text: 'Todas (${alocacoes.length})',
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
                              DataColumn(label: Text('Status pesquisa')),
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

                              final status =
                                  ((a['pesquisas']?['status']) ?? '')
                                      .toString();

                              final colaborador =
                                  ((a['profiles']?['nome']) ?? '').toString();

                              final email =
                                  ((a['profiles']?['email']) ?? '').toString();

                              final ativo =
                                  (a['profiles']?['ativo'] ?? false) == true;

                              return DataRow(
                                cells: [
                                  DataCell(Text(pesquisa)),
                                  DataCell(statusChip(status)),
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
                                          fontSize: 12,
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
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
          Expanded(
            child: Column(
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
  final _buscaColaboradorController = TextEditingController();

  List<Map<String, dynamic>> pesquisas = [];
  List<Map<String, dynamic>> colaboradores = [];
  Set<String> colaboradoresSelecionados = {};

  String? pesquisaId;

  bool loading = true;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _buscaColaboradorController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    try {
      final listaPesquisas = await _service.listarPesquisas();
      final listaColaboradores = await _service.listarColaboradores();

      if (!mounted) return;

      setState(() {
        pesquisas = listaPesquisas;
        colaboradores = listaColaboradores;
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

  List<Map<String, dynamic>> get colaboradoresFiltrados {
    final q = _buscaColaboradorController.text.trim().toLowerCase();

    if (q.isEmpty) return colaboradores;

    return colaboradores.where((c) {
      final nome = (c['nome'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();

      return nome.contains(q) || email.contains(q);
    }).toList();
  }

  void alternarTodosVisiveis() {
    final visiveis =
        colaboradoresFiltrados.map((c) => c['id'].toString()).toSet();

    final todosVisiveisSelecionados = visiveis.every(
      (id) => colaboradoresSelecionados.contains(id),
    );

    setState(() {
      if (todosVisiveisSelecionados) {
        colaboradoresSelecionados.removeAll(visiveis);
      } else {
        colaboradoresSelecionados.addAll(visiveis);
      }
    });
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (pesquisaId == null) return;

    if (colaboradoresSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um colaborador.')),
      );
      return;
    }

    setState(() => salvando = true);

    try {
      await _service.criarAlocacoesEmLote(
        pesquisaId: pesquisaId!,
        colaboradoresIds: colaboradoresSelecionados.toList(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar alocações: $e')),
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

    final todosVisiveisSelecionados = colaboradoresFiltrados.isNotEmpty &&
        colaboradoresFiltrados.every(
          (c) => colaboradoresSelecionados.contains(c['id'].toString()),
        );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SizedBox(
              height: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nova alocação em lote',
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
                      final titulo = (p['titulo'] ?? '').toString();
                      final status = (p['status'] ?? '').toString();

                      return DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(
                          status.isEmpty ? titulo : '$titulo ($status)',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => pesquisaId = value),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione a pesquisa'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _buscaColaboradorController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Buscar colaborador',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: colaboradoresFiltrados.isEmpty
                            ? null
                            : alternarTodosVisiveis,
                        icon: Icon(
                          todosVisiveisSelecionados
                              ? Icons.clear_all_rounded
                              : Icons.done_all_rounded,
                        ),
                        label: Text(
                          todosVisiveisSelecionados
                              ? 'Desmarcar visíveis'
                              : 'Selecionar visíveis',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${colaboradoresSelecionados.length} colaborador(es) selecionado(s)',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: colaboradoresFiltrados.isEmpty
                          ? const Center(
                              child: Text('Nenhum colaborador encontrado.'),
                            )
                          : ListView.separated(
                              itemCount: colaboradoresFiltrados.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final colaborador =
                                    colaboradoresFiltrados[index];
                                final id = colaborador['id'].toString();
                                final nome =
                                    (colaborador['nome'] ?? '').toString();
                                final email =
                                    (colaborador['email'] ?? '').toString();

                                final selecionado =
                                    colaboradoresSelecionados.contains(id);

                                return CheckboxListTile(
                                  value: selecionado,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        colaboradoresSelecionados.add(id);
                                      } else {
                                        colaboradoresSelecionados.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(nome),
                                  subtitle: Text(email),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: salvando
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: salvando ? null : salvar,
                        icon: salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.group_add_rounded),
                        label: Text(
                          salvando
                              ? 'Salvando...'
                              : 'Alocar ${colaboradoresSelecionados.length}',
                        ),
                      ),
                    ],
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