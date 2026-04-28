import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/questionarios_service.dart';
import '../services/pesquisas_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class QuestionariosPage extends StatefulWidget {
  const QuestionariosPage({super.key});

  @override
  State<QuestionariosPage> createState() => _QuestionariosPageState();
}

class _QuestionariosPageState extends State<QuestionariosPage>
    with SingleTickerProviderStateMixin {
  final QuestionariosService service = QuestionariosService();
  final PesquisasService pesquisasService = PesquisasService();
  final ProfileService profileService = ProfileService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  List<Map<String, dynamic>> lista = [];
  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    carregar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() => loading = true);

    try {
      final dados = await service.listar();
      final perfil = await profileService.getProfile();

      if (!mounted) return;

      setState(() {
        lista = dados;
        profile = perfil;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar questionários: $e')),
      );
    }
  }

Future<void> exportarPDF(Map<String, dynamic> questionarioResumo) async {
  try {
    final dados = await service.buscarDadosExportacao(
      questionarioResumo['id'].toString(),
    );

    final logoBytes =
      (await rootBundle.load('assets/images/logo_delta_quest.png'))
          .buffer
          .asUint8List();

    final logo = pw.MemoryImage(logoBytes); 
    final questionario = dados['questionario'] as Map<String, dynamic>;
    final blocos = dados['blocos'] as List<Map<String, dynamic>>;
    final perguntas = dados['perguntas'] as List<Map<String, dynamic>>;

    final pesquisa = questionario['pesquisas'] as Map<String, dynamic>?;
    final cliente = pesquisa?['clientes'] as Map<String, dynamic>?;

    final pdf = pw.Document();

    final titulo = (questionario['titulo'] ?? '').toString();
    final subtitulo = (questionario['subtitulo'] ?? '').toString();
    final descricao = (questionario['descricao'] ?? '').toString();

    final pesquisaTitulo = (pesquisa?['titulo'] ?? '').toString();
    final clienteNome = (cliente?['nome'] ??
            cliente?['razao_social'] ??
            cliente?['nome_fantasia'] ??
            'Cliente não informado')
        .toString();

    final data = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    List<Map<String, dynamic>> perguntasDoBloco(String? blocoId) {
      return perguntas.where((p) {
        return p['bloco_id']?.toString() == blocoId;
      }).toList();
    }

    String tipoLabel(String tipo) {
      switch (tipo) {
        case 'likert_1_5':
          return 'Likert (1 a 5)';
        case 'likert_1_10':
          return 'Likert (1 a 10)';
        case 'multipla':
          return 'Múltipla escolha';
        case 'unica':
          return 'Escolha única';
        default:
          return tipo;
      }
    }

    pw.Widget perguntaWidget(Map<String, dynamic> p) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${p['codigo'] ?? ''} ${p['texto']}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Tipo: ${tipoLabel(p['tipo'])}'),
            pw.Text('Obrigatória: ${p['obrigatoria'] == true ? 'Sim' : 'Não'}'),

            if (p['opcoes'] != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Opções:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: (p['opcoes'] as List)
                    .map((o) => pw.Text('- ${o['label'] ?? o['valor']}'))
                    .toList(),
              ),
            ],
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),

      header: (context) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 8),
  decoration: pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(width: 1, color: PdfColors.grey),
    ),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(
        children: [
          pw.Image(logo, width: 40),
          pw.SizedBox(width: 10),
          pw.Text(
            'DELTA QUEST IT',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
      pw.Text(
        'Página ${context.pageNumber}',
        style: const pw.TextStyle(fontSize: 10),
      ),
    ],
  ),
),

        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Gerado em $data',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),

        build: (context) {
          final widgets = <pw.Widget>[];

          // 📌 Cabeçalho principal
          widgets.add(
            pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );

          if (subtitulo.isNotEmpty) {
            widgets.add(
              pw.Text(
                subtitulo,
                style: pw.TextStyle(fontSize: 12),
              ),
            );
          }

          widgets.add(pw.SizedBox(height: 10));

          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Cliente: $clienteNome'),
                  pw.Text('Pesquisa: $pesquisaTitulo'),
                  if (descricao.isNotEmpty) pw.Text('Descrição: $descricao'),
                ],
              ),
            ),
          );

          widgets.add(pw.SizedBox(height: 20));

          // 📌 Blocos
          for (final bloco in blocos) {
            final perguntasBloco = perguntasDoBloco(bloco['id'].toString());

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  bloco['titulo'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
            );

            for (final p in perguntasBloco) {
              widgets.add(perguntaWidget(p));
            }
          }

          // 📌 Perguntas sem bloco
          final semBloco = perguntasDoBloco(null);

          if (semBloco.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Outras perguntas',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );

            for (final p in semBloco) {
              widgets.add(perguntaWidget(p));
            }
          }

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'questionario_$titulo.pdf',
      onLayout: (format) async => pdf.save(),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao gerar PDF: $e')),
    );
  }
}

  Future<void> exportarDOCX(Map<String, dynamic> questionario) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exportação DOCX será implementada na próxima etapa.'),
      ),
    );
  }

  Future<void> abrirFormulario({Map<String, dynamic>? questionario}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuestionarioDialog(questionario: questionario),
    );

    if (result == true) {
      await carregar();
    }
  }

  Future<void> excluir(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir questionário'),
        content: const Text('Deseja realmente excluir este questionário?'),
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

    await service.deletar(id);
    await carregar();
  }

  String _statusPesquisa(Map<String, dynamic> q) {
    return ((q['pesquisas']?['status']) ?? '').toString();
  }

  String _tituloPesquisa(Map<String, dynamic> q) {
    return ((q['pesquisas']?['titulo']) ?? '').toString();
  }

  String _tituloQuestionario(Map<String, dynamic> q) {
    return (q['titulo'] ?? '').toString();
  }

  List<Map<String, dynamic>> get _planejamento {
    return _filtrarPorStatusPesquisa('planejada');
  }

  List<Map<String, dynamic>> get _andamento {
    return _filtrarPorStatusPesquisa('em_andamento');
  }

  List<Map<String, dynamic>> get _concluidas {
    return _filtrarPorStatusPesquisa('concluida');
  }

  List<Map<String, dynamic>> get _canceladas {
    return _filtrarPorStatusPesquisa('cancelada');
  }

  List<Map<String, dynamic>> _filtrarPorStatusPesquisa(String status) {
    final query = _searchController.text.trim().toLowerCase();

    return lista.where((q) {
      final statusPesquisa = _statusPesquisa(q);
      if (statusPesquisa != status) return false;

      if (query.isEmpty) return true;

      final tituloQuestionario = _tituloQuestionario(q).toLowerCase();
      final subtituloQuestionario =
          (q['subtitulo'] ?? '').toString().toLowerCase();
      final tituloPesquisa = _tituloPesquisa(q).toLowerCase();
      final statusQuestionario =
          (q['status'] ?? '').toString().toLowerCase();

      return tituloQuestionario.contains(query) ||
          subtituloQuestionario.contains(query) ||
          tituloPesquisa.contains(query) ||
          statusPesquisa.toLowerCase().contains(query) ||
          statusQuestionario.contains(query);
    }).toList();
  }

  String formatarData(dynamic valor) {
    if (valor == null) return '-';

    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return '-';

    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String formatarStatusQuestionario(String status) {
    switch (status) {
      case 'rascunho':
        return 'Rascunho';
      case 'ativo':
        return 'Ativo';
      case 'finalizado':
        return 'Finalizado';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  Widget _buildStatusQuestionarioChip(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'rascunho':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        break;
      case 'ativo':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'finalizado':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
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
        formatarStatusQuestionario(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildResumoCard({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
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
            width: 52,
            height: 52,
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
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

  Widget _buildStatusPesquisaChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'planejada':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Planejada';
        break;
      case 'em_andamento':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Em andamento';
        break;
      case 'concluida':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Concluída';
        break;
      case 'cancelada':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Cancelada';
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
        label = status.isEmpty ? '-' : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTabela(List<Map<String, dynamic>> dados) {
    if (dados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('Nenhum questionário encontrado nesta aba.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFFF3F4F6),
        ),
        columns: const [
          DataColumn(label: Text('Questionário')),
          DataColumn(label: Text('Subtítulo')),
          DataColumn(label: Text('Pesquisa')),
          DataColumn(label: Text('Status questionário')),
          DataColumn(label: Text('Status pesquisa')),
          DataColumn(label: Text('Início')),
          DataColumn(label: Text('Fim')),
          DataColumn(label: Text('Perguntas')),
          DataColumn(label: Text('Atualização')),
          DataColumn(label: Text('Ações')),
        ],
        rows: dados.map((q) {
          final questionarioId = (q['id'] ?? '').toString();
          final questionarioTitulo = (q['titulo'] ?? '').toString();
          final questionarioSubtitulo = (q['subtitulo'] ?? '').toString();
          final statusQuestionario = (q['status'] ?? '').toString();
          final pesquisaTitulo = _tituloPesquisa(q);
          final statusPesquisa = _statusPesquisa(q);
          final dataInicio = q['pesquisas']?['data_inicio'];
          final dataFim = q['pesquisas']?['data_fim'];
          final perguntasCount = q['perguntas_count'] ?? 0;
          final updatedAt = q['updated_at'];

          return DataRow(
            cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(questionarioTitulo),
                ),
                onTap: () {
                  context.go(
                    '/perguntas/$questionarioId',
                    extra: {
                      'titulo': questionarioTitulo,
                      'pesquisaTitulo': pesquisaTitulo,
                    },
                  );
                },
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    questionarioSubtitulo.isEmpty
                        ? '-'
                        : questionarioSubtitulo,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(pesquisaTitulo),
                ),
              ),
              DataCell(_buildStatusQuestionarioChip(statusQuestionario)),
              DataCell(_buildStatusPesquisaChip(statusPesquisa)),
              DataCell(Text(formatarData(dataInicio))),
              DataCell(Text(formatarData(dataFim))),
              DataCell(Text(perguntasCount.toString())),
              DataCell(Text(formatarData(updatedAt))),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Abrir editor',
                      onPressed: () {
                        context.go(
                          '/perguntas/$questionarioId',
                          extra: {
                            'titulo': questionarioTitulo,
                            'pesquisaTitulo': pesquisaTitulo,
                          },
                        );
                      },
                      icon: const Icon(Icons.open_in_new_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Exportar',
                      icon: const Icon(Icons.download_outlined),
                      onSelected: (value) {
                        if (value == 'pdf') {
                          exportarPDF(q);
                        } else if (value == 'docx') {
                          exportarDOCX(q);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Exportar PDF'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'docx',
                          child: Row(
                            children: [
                              Icon(Icons.description_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Exportar DOCX'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => abrirFormulario(questionario: q),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      onPressed: () => excluir(questionarioId),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? '').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    return AdminShell(
      title: 'Questionários',
      userName: nome,
      userType: tipo,
      selectedIndex: 5,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestão de questionários',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de questionários: ${lista.length}',
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
                    _buildResumoCard(
                      titulo: 'Planejamento',
                      valor: _planejamento.length.toString(),
                      icone: Icons.event_note_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Em andamento',
                      valor: _andamento.length.toString(),
                      icone: Icons.play_circle_outline_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Concluídas',
                      valor: _concluidas.length.toString(),
                      icone: Icons.check_circle_outline_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Canceladas',
                      valor: _canceladas.length.toString(),
                      icone: Icons.cancel_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
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
                                    'Buscar por questionário, subtítulo, pesquisa ou status',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => abrirFormulario(),
                            icon: const Icon(Icons.add),
                            label: const Text('Novo Questionário'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: carregar,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Atualizar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF1D4ED8),
                        unselectedLabelColor: const Color(0xFF6B7280),
                        indicatorColor: const Color(0xFF1D4ED8),
                        tabs: const [
                          Tab(text: 'Em planejamento'),
                          Tab(text: 'Em andamento'),
                          Tab(text: 'Concluídas'),
                          Tab(text: 'Canceladas'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 520,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SingleChildScrollView(
                              child: _buildTabela(_planejamento),
                            ),
                            SingleChildScrollView(
                              child: _buildTabela(_andamento),
                            ),
                            SingleChildScrollView(
                              child: _buildTabela(_concluidas),
                            ),
                            SingleChildScrollView(
                              child: _buildTabela(_canceladas),
                            ),
                          ],
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

class QuestionarioDialog extends StatefulWidget {
  final Map<String, dynamic>? questionario;

  const QuestionarioDialog({
    super.key,
    this.questionario,
  });

  @override
  State<QuestionarioDialog> createState() => _QuestionarioDialogState();
}

class _QuestionarioDialogState extends State<QuestionarioDialog> {
  final QuestionariosService service = QuestionariosService();
  final PesquisasService pesquisasService = PesquisasService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController titulo = TextEditingController();
  final TextEditingController subtitulo = TextEditingController();
  final TextEditingController descricao = TextEditingController();

  List<Map<String, dynamic>> pesquisas = [];
  String? pesquisaId;
  String status = 'rascunho';
  bool loading = true;
  bool salvando = false;

  bool get editando => widget.questionario != null;

  @override
  void initState() {
    super.initState();

    titulo.text = widget.questionario?['titulo']?.toString() ?? '';
    subtitulo.text = widget.questionario?['subtitulo']?.toString() ?? '';
    descricao.text = widget.questionario?['descricao']?.toString() ?? '';
    status = widget.questionario?['status']?.toString() ?? 'rascunho';
    pesquisaId = widget.questionario?['pesquisa_id']?.toString();

    carregarPesquisas();
  }

  @override
  void dispose() {
    titulo.dispose();
    subtitulo.dispose();
    descricao.dispose();
    super.dispose();
  }

  Future<void> carregarPesquisas() async {
    try {
      final lista = await pesquisasService.listarPesquisas();

      if (!mounted) return;

      setState(() {
        pesquisas = lista;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar pesquisas: $e')),
      );
    }
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (pesquisaId == null || pesquisaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a pesquisa')),
      );
      return;
    }

    setState(() => salvando = true);

    try {
      if (editando) {
        await service.atualizar(
          id: widget.questionario!['id'].toString(),
          pesquisaId: pesquisaId!,
          titulo: titulo.text.trim(),
          subtitulo: subtitulo.text.trim(),
          descricao: descricao.text.trim(),
          status: status,
        );
      } else {
        await service.criar(
          pesquisaId: pesquisaId!,
          titulo: titulo.text.trim(),
          subtitulo: subtitulo.text.trim(),
          descricao: descricao.text.trim(),
          status: status,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar questionário: $e')),
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
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editando ? 'Editar Questionário' : 'Novo Questionário',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: pesquisaId,
                  items: pesquisas.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text((p['titulo'] ?? '').toString()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => pesquisaId = v),
                  decoration: const InputDecoration(
                    labelText: 'Pesquisa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Selecione a pesquisa' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titulo,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o título' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: subtitulo,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status do questionário',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'rascunho',
                      child: Text('Rascunho'),
                    ),
                    DropdownMenuItem(
                      value: 'ativo',
                      child: Text('Ativo'),
                    ),
                    DropdownMenuItem(
                      value: 'finalizado',
                      child: Text('Finalizado'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v ?? 'rascunho'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descricao,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
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