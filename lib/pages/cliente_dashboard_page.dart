import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteDashboardPage extends StatefulWidget {
  const ClienteDashboardPage({super.key});

  @override
  State<ClienteDashboardPage> createState() => _ClienteDashboardPageState();
}

class _ClienteDashboardPageState extends State<ClienteDashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> pesquisas = [];

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => loading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      final perfil = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final vinculos = await supabase
          .from('usuarios_clientes')
          .select('''
            cliente_id,
            clientes (
              id,
              nome,
              razao_social,
              nome_fantasia
            )
          ''')
          .eq('user_id', userId);

      final listaVinculos = List<Map<String, dynamic>>.from(vinculos);

      final clienteIds = listaVinculos
          .map((v) => v['cliente_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (clienteIds.isEmpty) {
        throw Exception('Usuário não vinculado a nenhum cliente.');
      }

      final pesquisasData = await supabase
          .from('pesquisas')
          .select('''
            id,
            cliente_id,
            titulo,
            descricao,
            status,
            data_inicio,
            data_fim,
            meta_respostas,
            created_at,
            entrevistas (
              id,
              status,
              deleted_at
            ),
            questionarios (
              id,
              titulo,
              subtitulo,
              status,
              deleted_at
            )
          ''')
          .inFilter('cliente_id', clienteIds)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        profile = perfil;
        clientes = listaVinculos
            .map((v) => Map<String, dynamic>.from(v['clientes'] ?? {}))
            .where((c) => c.isNotEmpty)
            .toList();
        pesquisas = List<Map<String, dynamic>>.from(pesquisasData);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dashboard: $e')),
      );
    }
  }

  void _abrirPerfil() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Meu perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nome: ${profile?['nome'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('E-mail: ${profile?['email'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Perfil: ${profile?['tipo'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _abrirAlterarSenha() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alterar senha'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nova senha',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('A senha deve ter pelo menos 6 caracteres.'),
                  ),
                );
                return;
              }

              await supabase.auth.updateUser(
                UserAttributes(password: controller.text.trim()),
              );

              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Senha alterada com sucesso.')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _abrirConfiguracoes() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Configurações'),
        content: const Text(
          'Configurações do portal do cliente serão disponibilizadas em breve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  int get totalPesquisas => pesquisas.length;

  int get totalQuestionarios {
    int total = 0;

    for (final p in pesquisas) {
      final qs = p['questionarios'];
      if (qs is List) {
        total += qs.where((q) => q['deleted_at'] == null).length;
      }
    }

    return total;
  }

  int get totalEmAndamento {
    return pesquisas.where((p) {
      final status = (p['status'] ?? '').toString();
      return status == 'em_andamento' || status == 'planejada';
    }).length;
  }

  int get totalFinalizadas {
    return pesquisas.where((p) {
      return (p['status'] ?? '').toString() == 'concluida';
    }).length;
  }

  String formatarData(dynamic valor) {
    if (valor == null) return '-';

    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return '-';

    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String formatarStatus(String status) {
    switch (status) {
      case 'planejada':
        return 'Planejada';
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Finalizada';
      case 'pausada':
        return 'Pausada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  int metaRespostas(Map<String, dynamic> pesquisa) {
    final raw = pesquisa['meta_respostas'];

    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is double) return raw.round();

    return int.tryParse(raw.toString()) ?? 0;
  }

  int contarEntrevistasConcluidas(Map<String, dynamic> pesquisa) {
    final entrevistas = pesquisa['entrevistas'];

    if (entrevistas is! List) return 0;

    return entrevistas.where((e) {
      final status = (e['status'] ?? '').toString();
      final deletedAt = e['deleted_at'];

      return status == 'concluida' && deletedAt == null;
    }).length;
  }

  int contarEntrevistasPendentes(Map<String, dynamic> pesquisa) {
    final entrevistas = pesquisa['entrevistas'];

    if (entrevistas is! List) return 0;

    return entrevistas.where((e) {
      final status = (e['status'] ?? '').toString();
      final deletedAt = e['deleted_at'];

      return status == 'pendente' && deletedAt == null;
    }).length;
  }

  int calcularProgresso(Map<String, dynamic> pesquisa) {
    final meta = metaRespostas(pesquisa);

    if (meta <= 0) return 0;

    final concluidas = contarEntrevistasConcluidas(pesquisa);

    final progresso = ((concluidas / meta) * 100).round();

    return progresso.clamp(0, 100);
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
      case 'pausada':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatarStatus(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget progressoWidget(Map<String, dynamic> pesquisa) {
    final progresso = calcularProgresso(pesquisa);
    final meta = metaRespostas(pesquisa);
    final concluidas = contarEntrevistasConcluidas(pesquisa);
    final pendentes = contarEntrevistasPendentes(pesquisa);

    final textoAuxiliar = meta > 0
        ? '$concluidas / $meta entrevistas'
        : '$concluidas entrevistas concluídas';

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progresso / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progresso%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            pendentes > 0
                ? '$textoAuxiliar • $pendentes pendente(s)'
                : textoAuxiliar,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  int contarQuestionarios(Map<String, dynamic> pesquisa) {
    final qs = pesquisa['questionarios'];
    if (qs is! List) return 0;

    return qs.where((q) => q['deleted_at'] == null).length;
  }

  List<Map<String, dynamic>> questionariosDaPesquisa(
    Map<String, dynamic> pesquisa,
  ) {
    final qs = pesquisa['questionarios'];

    if (qs is! List) return [];

    return qs
        .where((q) => q['deleted_at'] == null)
        .map((q) => Map<String, dynamic>.from(q))
        .toList();
  }

  Future<void> exportarQuestionario(Map<String, dynamic> questionario) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exportação do questionário "${questionario['titulo']}" será integrada aqui.',
        ),
      ),
    );
  }

  Future<void> exportarRelatorio(Map<String, dynamic> pesquisa) async {
    final status = (pesquisa['status'] ?? '').toString();

    if (status != 'concluida') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O relatório final estará disponível quando a pesquisa for finalizada.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Relatório final da pesquisa "${pesquisa['titulo']}" será integrado aqui.',
        ),
      ),
    );
  }

  Future<void> sair() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    context.go('/login');
  }

  Widget resumoCard({
    required String titulo,
    required String valor,
    required IconData icone,
    required String subtitulo,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icone,
              color: const Color(0xFF2563EB),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String nomeClientePrincipal() {
    if (clientes.isEmpty) return 'Cliente';

    final c = clientes.first;

    return (c['nome'] ??
            c['razao_social'] ??
            c['nome_fantasia'] ??
            'Cliente')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final nomeUsuario = (profile?['nome'] ?? 'Cliente').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 72,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'DQ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delta Quest IT',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: PopupMenuButton<String>(
              tooltip: 'Menu do usuário',
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) async {
                if (value == 'perfil') {
                  _abrirPerfil();
                }

                if (value == 'senha') {
                  _abrirAlterarSenha();
                }

                if (value == 'configuracoes') {
                  _abrirConfiguracoes();
                }

                if (value == 'sair') {
                  await sair();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'perfil',
                  child: Text('Meu perfil'),
                ),
                PopupMenuItem(
                  value: 'senha',
                  child: Text('Alterar senha'),
                ),
                PopupMenuItem(
                  value: 'configuracoes',
                  child: Text('Configurações'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'sair',
                  child: Text('Sair'),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        nomeUsuario.isNotEmpty
                            ? nomeUsuario.substring(0, 1).toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      nomeUsuario,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF111827),
                              Color(0xFF1D4ED8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Portal do Cliente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nomeClientePrincipal(),
                              style: const TextStyle(
                                color: Color(0xFFE5E7EB),
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Acompanhe suas pesquisas contratadas, questionários disponíveis e relatórios finais em um único painel.',
                              style: TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          resumoCard(
                            titulo: 'Pesquisas contratadas',
                            valor: totalPesquisas.toString(),
                            subtitulo: 'Total no sistema',
                            icone: Icons.assignment_outlined,
                          ),
                          resumoCard(
                            titulo: 'Questionários',
                            valor: totalQuestionarios.toString(),
                            subtitulo: 'Instrumentos vinculados',
                            icone: Icons.fact_check_outlined,
                          ),
                          resumoCard(
                            titulo: 'Em andamento',
                            valor: totalEmAndamento.toString(),
                            subtitulo: 'Pesquisas ativas/planejadas',
                            icone: Icons.play_circle_outline_rounded,
                          ),
                          resumoCard(
                            titulo: 'Finalizadas',
                            valor: totalFinalizadas.toString(),
                            subtitulo: 'Pesquisas concluídas',
                            icone: Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesquisas contratadas',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Consulte o status, o andamento, os questionários e os relatórios finais das pesquisas.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (pesquisas.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: Center(
                                  child: Text(
                                    'Nenhuma pesquisa vinculada a este cliente.',
                                  ),
                                ),
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
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Início')),
                                    DataColumn(label: Text('Fim')),
                                    DataColumn(label: Text('Questionários')),
                                    DataColumn(label: Text('Progresso')),
                                    DataColumn(label: Text('Ações')),
                                  ],
                                  rows: pesquisas.map((p) {
                                    final titulo =
                                        (p['titulo'] ?? '').toString();
                                    final status =
                                        (p['status'] ?? '').toString();
                                    final questionarios =
                                        questionariosDaPesquisa(p);
                                    final concluida = status == 'concluida';

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 320,
                                            ),
                                            child: Text(
                                              titulo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(statusChip(status)),
                                        DataCell(
                                          Text(formatarData(p['data_inicio'])),
                                        ),
                                        DataCell(
                                          Text(formatarData(p['data_fim'])),
                                        ),
                                        DataCell(
                                          Text(questionarios.length.toString()),
                                        ),
                                        DataCell(progressoWidget(p)),
                                        DataCell(
                                          Row(
                                            children: [
                                              PopupMenuButton<String>(
                                                tooltip:
                                                    'Exportar questionário',
                                                enabled:
                                                    questionarios.isNotEmpty,
                                                icon: const Icon(
                                                  Icons.description_outlined,
                                                ),
                                                onSelected: (id) {
                                                  final q =
                                                      questionarios.firstWhere(
                                                    (x) =>
                                                        x['id'].toString() ==
                                                        id,
                                                  );
                                                  exportarQuestionario(q);
                                                },
                                                itemBuilder: (context) {
                                                  if (questionarios.isEmpty) {
                                                    return const [
                                                      PopupMenuItem(
                                                        value: '',
                                                        child: Text(
                                                          'Nenhum questionário',
                                                        ),
                                                      ),
                                                    ];
                                                  }

                                                  return questionarios.map((q) {
                                                    return PopupMenuItem(
                                                      value:
                                                          q['id'].toString(),
                                                      child: Text(
                                                        (q['titulo'] ?? '')
                                                            .toString(),
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                              ),
                                              const SizedBox(width: 6),
                                              Tooltip(
                                                message: concluida
                                                    ? 'Exportar relatório final'
                                                    : 'Disponível quando a pesquisa for finalizada',
                                                child: OutlinedButton.icon(
                                                  onPressed: concluida
                                                      ? () =>
                                                          exportarRelatorio(p)
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.bar_chart_rounded,
                                                  ),
                                                  label: const Text(
                                                    'Relatório final',
                                                  ),
                                                ),
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
                ),
              ),
            ),
    );
  }
}