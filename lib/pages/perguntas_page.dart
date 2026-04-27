import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:universal_html/html.dart' as html;

import '../services/import_excel_service.dart';
import '../services/perguntas_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class PerguntasPage extends StatefulWidget {
  final String questionarioId;
  final String questionarioTitulo;
  final String pesquisaTitulo;

  const PerguntasPage({
    super.key,
    required this.questionarioId,
    required this.questionarioTitulo,
    required this.pesquisaTitulo,
  });

  @override
  State<PerguntasPage> createState() => _PerguntasPageState();
}

class _PerguntasPageState extends State<PerguntasPage> {
  final PerguntasService service = PerguntasService();
  final ProfileService profileService = ProfileService();
  final ImportExcelService importService = ImportExcelService();

  List<Map<String, dynamic>> blocos = [];
  List<Map<String, dynamic>> perguntas = [];
  List<Map<String, dynamic>> regrasPulo = [];

  Map<String, dynamic>? profile;

  bool loading = true;
  bool importing = false;
  bool downloading = false;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => loading = true);

    try {
      final listaPerguntas = await service.listar(widget.questionarioId);
      final listaBlocos = await service.listarBlocos(widget.questionarioId);
      final listaRegras = await service.listarRegrasPulo(widget.questionarioId);
      final perfil = await profileService.getProfile();

      if (!mounted) return;

      setState(() {
        perguntas = listaPerguntas;
        blocos = listaBlocos;
        regrasPulo = listaRegras;
        profile = perfil;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar editor: $e')),
      );
    }
  }

  Future<void> importarExcel() async {
    setState(() => importing = true);

    try {
      await importService.importarPerguntas(widget.questionarioId);
      await carregar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perguntas importadas com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na importação: $e')),
      );
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> baixarModeloExcel() async {
    setState(() => downloading = true);

    try {
      final ByteData data =
          await rootBundle.load('assets/templates/modelo_questionario.xlsx');
      final Uint8List bytes = data.buffer.asUint8List();

      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', 'modelo_questionario.xlsx')
        ..click();

      html.Url.revokeObjectUrl(url);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download do modelo iniciado')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao baixar modelo: $e')),
      );
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  List<Map<String, dynamic>> perguntasDoBloco(String? blocoId) {
    return perguntas.where((p) {
      final id = p['bloco_id']?.toString();
      return id == blocoId;
    }).toList()
      ..sort((a, b) {
        final oa = int.tryParse((a['ordem'] ?? 0).toString()) ?? 0;
        final ob = int.tryParse((b['ordem'] ?? 0).toString()) ?? 0;
        return oa.compareTo(ob);
      });
  }

  int get totalComPulo {
    return perguntas.where((p) {
      final destino = p['pergunta_destino_nao_se_aplica'];
      return destino != null || regrasPulo.any((r) {
        return r['pergunta_origem_id']?.toString() == p['id']?.toString();
      });
    }).length;
  }

  Future<void> abrirBloco({Map<String, dynamic>? bloco}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocoDialog(
        questionarioId: widget.questionarioId,
        bloco: bloco,
      ),
    );

    if (result == true) await carregar();
  }

  Future<void> abrirPergunta({
    Map<String, dynamic>? pergunta,
    String? blocoId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PerguntaDialog(
        questionarioId: widget.questionarioId,
        pergunta: pergunta,
        blocoIdInicial: blocoId,
        blocos: blocos,
        perguntas: perguntas,
      ),
    );

    if (result == true) await carregar();
  }

  Future<void> abrirRegraPulo(Map<String, dynamic> pergunta) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegraPuloDialog(
        perguntaOrigem: pergunta,
        perguntas: perguntas,
        regras: regrasPulo
            .where(
              (r) =>
                  r['pergunta_origem_id']?.toString() ==
                  pergunta['id']?.toString(),
            )
            .toList(),
      ),
    );

    if (result == true) await carregar();
  }

  Future<void> excluirPergunta(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir pergunta'),
        content: const Text('Deseja realmente excluir esta pergunta?'),
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

  Future<void> excluirBloco(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir bloco'),
        content: const Text(
          'Deseja realmente excluir este bloco? As perguntas vinculadas ficarão sem bloco.',
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

    await service.deletarBloco(id);
    await carregar();
  }

  String traduzirTipo(String tipo) {
    switch (tipo) {
      case 'texto':
        return 'Texto curto';
      case 'texto_longo':
        return 'Texto longo';
      case 'numero':
        return 'Número';
      case 'unica':
        return 'Escolha única';
      case 'multipla':
        return 'Múltipla escolha';
      case 'booleano':
        return 'Sim/Não';
      case 'likert_1_5':
        return 'Likert 1–5';
      case 'likert_1_10':
        return 'Likert 1–10';
      case 'emoji':
        return 'Emoji';
      default:
        return tipo.isEmpty ? '-' : tipo;
    }
  }

  Widget tipoChip(String tipo) {
    return _chip(
      label: traduzirTipo(tipo),
      bg: const Color(0xFFEFF6FF),
      fg: const Color(0xFF2563EB),
    );
  }

  Widget obrigatoriaChip(bool value) {
    return _chip(
      label: value ? 'Obrigatória' : 'Opcional',
      bg: value ? const Color(0xFFFEE2E2) : const Color(0xFFE5E7EB),
      fg: value ? const Color(0xFF991B1B) : const Color(0xFF374151),
    );
  }

  Widget naoSeAplicaChip(bool value) {
    return _chip(
      label: value ? 'Permite N/A' : 'Sem N/A',
      bg: value ? const Color(0xFFF3E8FF) : const Color(0xFFE5E7EB),
      fg: value ? const Color(0xFF7E22CE) : const Color(0xFF374151),
    );
  }

  Widget _chip({
    required String label,
    required Color bg,
    required Color fg,
  }) {
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

  String resumoOpcoes(dynamic opcoes, String tipo) {
    if (tipo == 'likert_1_5') return '1, 2, 3, 4, 5';
    if (tipo == 'likert_1_10') return '1 a 10';
    if (tipo == 'emoji') return '😡 🙁 😐 🙂 😄';

    if (opcoes == null) return '-';

    if (opcoes is List) {
      return opcoes.map((e) {
        if (e is Map) {
          return (e['label'] ?? e['valor'] ?? '').toString();
        }
        return e.toString();
      }).join(', ');
    }

    final texto = opcoes.toString();
    return texto.isEmpty ? '-' : texto;
  }

  String nomePerguntaDestino(dynamic destinoId) {
    if (destinoId == null) return '-';

    final destino = perguntas.where((p) {
      return p['id']?.toString() == destinoId.toString();
    }).firstOrNull;

    if (destino == null) return '-';

    final codigo = (destino['codigo'] ?? '').toString();
    final texto = (destino['texto'] ?? '').toString();

    if (codigo.isNotEmpty) return '$codigo - $texto';
    return texto;
  }

  Widget perguntaCard(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final codigo = (p['codigo'] ?? '').toString();
    final texto = (p['texto'] ?? '').toString();
    final subtitulo = (p['subtitulo'] ?? '').toString();
    final tipo = (p['tipo'] ?? '').toString();
    final obrigatoria = p['obrigatoria'] == true;
    final classificatoria = p['classificatoria'] == true;
    final permiteNaoSeAplica = p['permite_nao_se_aplica'] == true;
    final destinoNA = p['pergunta_destino_nao_se_aplica'];
    final regras = regrasPulo.where((r) {
      return r['pergunta_origem_id']?.toString() == id;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  (p['ordem'] ?? '-').toString(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  codigo.isNotEmpty ? '$codigo — $texto' : texto,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Editar pergunta',
                onPressed: () => abrirPergunta(pergunta: p),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Regras de pulo',
                onPressed: () => abrirRegraPulo(p),
                icon: const Icon(Icons.call_split_rounded),
              ),
              IconButton(
                tooltip: 'Excluir pergunta',
                onPressed: () => excluirPergunta(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (subtitulo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                subtitulo,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                tipoChip(tipo),
                obrigatoriaChip(obrigatoria),
                naoSeAplicaChip(permiteNaoSeAplica),
                if (classificatoria)
                  _chip(
                    label: 'Classificatória',
                    bg: const Color(0xFFFEF3C7),
                    fg: const Color(0xFFB45309),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'Opções: ${resumoOpcoes(p['opcoes'], tipo)}',
              style: const TextStyle(color: Color(0xFF374151)),
            ),
          ),
          if (permiteNaoSeAplica) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                'Não se aplica → ${nomePerguntaDestino(destinoNA)}',
                style: const TextStyle(color: Color(0xFF7E22CE)),
              ),
            ),
          ],
          if (regras.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: regras.map((r) {
                  final valor = (r['valor_resposta'] ?? '').toString();
                  final encerrar = r['encerrar_questionario'] == true;
                  final destino = r['pergunta_destino_id'];

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      encerrar
                          ? 'Se resposta = "$valor" → encerrar questionário'
                          : 'Se resposta = "$valor" → ${nomePerguntaDestino(destino)}',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget blocoCard(Map<String, dynamic> bloco) {
    final id = bloco['id']?.toString() ?? '';
    final titulo = (bloco['titulo'] ?? '').toString();
    final descricao = (bloco['descricao'] ?? '').toString();
    final perguntasBloco = perguntasDoBloco(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.view_agenda_outlined, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              Text(
                '${perguntasBloco.length} pergunta(s)',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Nova pergunta neste bloco',
                onPressed: () => abrirPergunta(blocoId: id),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Editar bloco',
                onPressed: () => abrirBloco(bloco: bloco),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir bloco',
                onPressed: () => excluirBloco(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (perguntasBloco.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhuma pergunta neste bloco.'),
            )
          else
            Column(
              children: perguntasBloco.map(perguntaCard).toList(),
            ),
        ],
      ),
    );
  }

  Widget resumoCard({
    required String titulo,
    required String valor,
    required IconData icon,
  }) {
    return Container(
      width: 220,
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
            child: Icon(icon, color: const Color(0xFF2563EB)),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? '').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    final perguntasSemBloco = perguntasDoBloco(null);

    return AdminShell(
      title: 'Editor de questionário',
      userName: nome,
      userType: tipo,
      selectedIndex: 5,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/questionarios'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.questionarioTitulo,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pesquisa: ${widget.pesquisaTitulo}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      resumoCard(
                        titulo: 'Perguntas',
                        valor: perguntas.length.toString(),
                        icon: Icons.help_outline_rounded,
                      ),
                      resumoCard(
                        titulo: 'Blocos',
                        valor: blocos.length.toString(),
                        icon: Icons.view_agenda_outlined,
                      ),
                      resumoCard(
                        titulo: 'Com pulo',
                        valor: totalComPulo.toString(),
                        icon: Icons.call_split_rounded,
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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => abrirBloco(),
                          icon: const Icon(Icons.view_agenda_outlined),
                          label: const Text('Novo bloco'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => abrirPergunta(),
                          icon: const Icon(Icons.add),
                          label: const Text('Nova pergunta'),
                        ),
                        ElevatedButton.icon(
                          onPressed: importing ? null : importarExcel,
                          icon: importing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                          label: const Text('Importar Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: downloading ? null : baixarModeloExcel,
                          icon: downloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: const Text('Baixar modelo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: carregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (blocos.isEmpty && perguntasSemBloco.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Nenhuma pergunta cadastrada.'),
                      ),
                    )
                  else ...[
                    ...blocos.map(blocoCard),
                    if (perguntasSemBloco.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perguntas sem bloco',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...perguntasSemBloco.map(perguntaCard),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class BlocoDialog extends StatefulWidget {
  final String questionarioId;
  final Map<String, dynamic>? bloco;

  const BlocoDialog({
    super.key,
    required this.questionarioId,
    this.bloco,
  });

  @override
  State<BlocoDialog> createState() => _BlocoDialogState();
}

class _BlocoDialogState extends State<BlocoDialog> {
  final _formKey = GlobalKey<FormState>();
  final service = PerguntasService();

  final titulo = TextEditingController();
  final descricao = TextEditingController();
  final ordem = TextEditingController(text: '1');

  bool salvando = false;

  bool get editando => widget.bloco != null;

  @override
  void initState() {
    super.initState();

    titulo.text = widget.bloco?['titulo']?.toString() ?? '';
    descricao.text = widget.bloco?['descricao']?.toString() ?? '';
    ordem.text = widget.bloco?['ordem']?.toString() ?? '1';
  }

  @override
  void dispose() {
    titulo.dispose();
    descricao.dispose();
    ordem.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => salvando = true);

    try {
      if (editando) {
        await service.atualizarBloco(
          id: widget.bloco!['id'].toString(),
          titulo: titulo.text.trim(),
          descricao: descricao.text.trim(),
          ordem: int.tryParse(ordem.text.trim()) ?? 1,
        );
      } else {
        await service.criarBloco(
          questionarioId: widget.questionarioId,
          titulo: titulo.text.trim(),
          descricao: descricao.text.trim(),
          ordem: int.tryParse(ordem.text.trim()) ?? 1,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar bloco: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  editando ? 'Editar bloco' : 'Novo bloco',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titulo,
                  decoration: const InputDecoration(
                    labelText: 'Título do bloco',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o título' : null,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: ordem,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ordem',
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

class PerguntaDialog extends StatefulWidget {
  final String questionarioId;
  final Map<String, dynamic>? pergunta;
  final String? blocoIdInicial;
  final List<Map<String, dynamic>> blocos;
  final List<Map<String, dynamic>> perguntas;

  const PerguntaDialog({
    super.key,
    required this.questionarioId,
    this.pergunta,
    this.blocoIdInicial,
    required this.blocos,
    required this.perguntas,
  });

  @override
  State<PerguntaDialog> createState() => _PerguntaDialogState();
}

class _PerguntaDialogState extends State<PerguntaDialog> {
  final service = PerguntasService();
  final _formKey = GlobalKey<FormState>();

  final codigo = TextEditingController();
  final texto = TextEditingController();
  final subtitulo = TextEditingController();
  final opcoes = TextEditingController();
  final ordem = TextEditingController(text: '1');
  final ajuda = TextEditingController();

  String tipo = 'texto';
  String? blocoId;
  String? destinoNaoSeAplicaId;

  bool obrigatoria = true;
  bool classificatoria = false;
  bool permiteNaoSeAplica = false;
  bool salvando = false;

  bool get editando => widget.pergunta != null;

  @override
  void initState() {
    super.initState();

    final p = widget.pergunta;

    codigo.text = p?['codigo']?.toString() ?? '';
    texto.text = p?['texto']?.toString() ?? '';
    subtitulo.text = p?['subtitulo']?.toString() ?? '';
    ordem.text = p?['ordem']?.toString() ?? '1';
    ajuda.text = p?['ajuda']?.toString() ?? '';

    tipo = p?['tipo']?.toString() ?? 'texto';
    blocoId = p?['bloco_id']?.toString() ?? widget.blocoIdInicial;
    destinoNaoSeAplicaId =
        p?['pergunta_destino_nao_se_aplica']?.toString();

    obrigatoria = p?['obrigatoria'] == true || p == null;
    classificatoria = p?['classificatoria'] == true;
    permiteNaoSeAplica = p?['permite_nao_se_aplica'] == true;

    final o = p?['opcoes'];

    if (o is List) {
      opcoes.text = o.map((e) {
        if (e is Map) return (e['label'] ?? e['valor'] ?? '').toString();
        return e.toString();
      }).join(' | ');
    }
  }

  @override
  void dispose() {
    codigo.dispose();
    texto.dispose();
    subtitulo.dispose();
    opcoes.dispose();
    ordem.dispose();
    ajuda.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get perguntasDestino {
    final atualId = widget.pergunta?['id']?.toString();

    return widget.perguntas.where((p) {
      return p['id']?.toString() != atualId;
    }).toList();
  }

  bool get usaOpcoes {
    return tipo == 'unica' || tipo == 'multipla';
  }

  bool get usaEscala {
    return tipo == 'likert_1_5' || tipo == 'likert_1_10' || tipo == 'emoji';
  }

  List<Map<String, dynamic>> montarOpcoes() {
    if (tipo == 'likert_1_5') {
      return [
        {'valor': 1, 'label': 'Discordo totalmente'},
        {'valor': 2, 'label': 'Discordo'},
        {'valor': 3, 'label': 'Neutro'},
        {'valor': 4, 'label': 'Concordo'},
        {'valor': 5, 'label': 'Concordo totalmente'},
      ];
    }

    if (tipo == 'likert_1_10') {
      return List.generate(10, (i) {
        return {'valor': i + 1, 'label': '${i + 1}'};
      });
    }

    if (tipo == 'emoji') {
      return [
        {'valor': 1, 'emoji': '😡', 'label': 'Muito insatisfeito'},
        {'valor': 2, 'emoji': '🙁', 'label': 'Insatisfeito'},
        {'valor': 3, 'emoji': '😐', 'label': 'Neutro'},
        {'valor': 4, 'emoji': '🙂', 'label': 'Satisfeito'},
        {'valor': 5, 'emoji': '😄', 'label': 'Muito satisfeito'},
      ];
    }

    if (usaOpcoes) {
      return opcoes.text
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => {'valor': e, 'label': e})
          .toList();
    }

    return [];
  }

  int? escalaMin() {
    if (tipo == 'likert_1_5' || tipo == 'likert_1_10' || tipo == 'emoji') {
      return 1;
    }
    return null;
  }

  int? escalaMax() {
    if (tipo == 'likert_1_5' || tipo == 'emoji') return 5;
    if (tipo == 'likert_1_10') return 10;
    return null;
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (permiteNaoSeAplica &&
        destinoNaoSeAplicaId != null &&
        destinoNaoSeAplicaId!.isEmpty) {
      destinoNaoSeAplicaId = null;
    }

    setState(() => salvando = true);

    try {
      final opcoesMontadas = montarOpcoes();

      if (editando) {
        await service.atualizar(
          id: widget.pergunta!['id'].toString(),
          questionarioId: widget.questionarioId,
          blocoId: blocoId,
          codigo: codigo.text.trim(),
          texto: texto.text.trim(),
          subtitulo: subtitulo.text.trim(),
          tipo: tipo,
          ordem: int.tryParse(ordem.text.trim()) ?? 1,
          obrigatoria: obrigatoria,
          classificatoria: classificatoria,
          permiteNaoSeAplica: permiteNaoSeAplica,
          perguntaDestinoNaoSeAplica: permiteNaoSeAplica
              ? destinoNaoSeAplicaId
              : null,
          opcoes: opcoesMontadas.isEmpty ? null : opcoesMontadas,
          escalaMin: escalaMin(),
          escalaMax: escalaMax(),
          emojiMap: tipo == 'emoji' ? opcoesMontadas : null,
          ajuda: ajuda.text.trim(),
        );
      } else {
        await service.criar(
          questionarioId: widget.questionarioId,
          blocoId: blocoId,
          codigo: codigo.text.trim(),
          texto: texto.text.trim(),
          subtitulo: subtitulo.text.trim(),
          tipo: tipo,
          ordem: int.tryParse(ordem.text.trim()) ?? 1,
          obrigatoria: obrigatoria,
          classificatoria: classificatoria,
          permiteNaoSeAplica: permiteNaoSeAplica,
          perguntaDestinoNaoSeAplica: permiteNaoSeAplica
              ? destinoNaoSeAplicaId
              : null,
          opcoes: opcoesMontadas.isEmpty ? null : opcoesMontadas,
          escalaMin: escalaMin(),
          escalaMax: escalaMax(),
          emojiMap: tipo == 'emoji' ? opcoesMontadas : null,
          ajuda: ajuda.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar pergunta: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Widget campo({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editando ? 'Editar pergunta' : 'Nova pergunta',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: campo(
                          controller: ordem,
                          label: 'Ordem',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campo(
                          controller: codigo,
                          label: 'Código',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: blocoId,
                          decoration: const InputDecoration(
                            labelText: 'Bloco',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sem bloco'),
                            ),
                            ...widget.blocos.map((b) {
                              return DropdownMenuItem<String?>(
                                value: b['id'].toString(),
                                child: Text((b['titulo'] ?? '').toString()),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => blocoId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  campo(
                    controller: texto,
                    label: 'Pergunta',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe a pergunta' : null,
                  ),
                  const SizedBox(height: 12),
                  campo(
                    controller: subtitulo,
                    label: 'Subtítulo / instrução da pergunta',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo da pergunta',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'texto', child: Text('Texto curto')),
                      DropdownMenuItem(value: 'texto_longo', child: Text('Texto longo')),
                      DropdownMenuItem(value: 'numero', child: Text('Número')),
                      DropdownMenuItem(value: 'booleano', child: Text('Sim/Não')),
                      DropdownMenuItem(value: 'unica', child: Text('Escolha única')),
                      DropdownMenuItem(value: 'multipla', child: Text('Múltipla escolha')),
                      DropdownMenuItem(value: 'likert_1_5', child: Text('Likert 1 a 5')),
                      DropdownMenuItem(value: 'likert_1_10', child: Text('Likert 1 a 10')),
                      DropdownMenuItem(value: 'emoji', child: Text('Emoji')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => tipo = v);
                    },
                  ),
                  if (usaOpcoes) ...[
                    const SizedBox(height: 12),
                    campo(
                      controller: opcoes,
                      label: 'Opções separadas por |',
                      validator: (v) {
                        if (usaOpcoes && (v == null || v.trim().isEmpty)) {
                          return 'Informe as opções';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (usaEscala) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        tipo == 'emoji'
                            ? 'Escala emoji: 😡=1, 🙁=2, 😐=3, 🙂=4, 😄=5'
                            : tipo == 'likert_1_5'
                                ? 'Escala Likert 1 a 5 será criada automaticamente.'
                                : 'Escala Likert 1 a 10 será criada automaticamente.',
                        style: const TextStyle(color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  campo(
                    controller: ajuda,
                    label: 'Texto de ajuda',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: obrigatoria,
                    title: const Text('Pergunta obrigatória'),
                    onChanged: (v) => setState(() => obrigatoria = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: classificatoria,
                    title: const Text('Pergunta classificatória'),
                    onChanged: (v) => setState(() => classificatoria = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: permiteNaoSeAplica,
                    title: const Text('Permitir botão "Não se aplica"'),
                    onChanged: (v) => setState(() => permiteNaoSeAplica = v),
                  ),
                  if (permiteNaoSeAplica) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: destinoNaoSeAplicaId,
                      decoration: const InputDecoration(
                        labelText: 'Se marcar "Não se aplica", pular para',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Não pular'),
                        ),
                        ...perguntasDestino.map((p) {
                          final codigo = (p['codigo'] ?? '').toString();
                          final texto = (p['texto'] ?? '').toString();

                          return DropdownMenuItem<String?>(
                            value: p['id'].toString(),
                            child: Text(codigo.isNotEmpty ? '$codigo - $texto' : texto),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => destinoNaoSeAplicaId = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: salvando ? null : () => Navigator.pop(context, false),
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
      ),
    );
  }
}

class RegraPuloDialog extends StatefulWidget {
  final Map<String, dynamic> perguntaOrigem;
  final List<Map<String, dynamic>> perguntas;
  final List<Map<String, dynamic>> regras;

  const RegraPuloDialog({
    super.key,
    required this.perguntaOrigem,
    required this.perguntas,
    required this.regras,
  });

  @override
  State<RegraPuloDialog> createState() => _RegraPuloDialogState();
}

class _RegraPuloDialogState extends State<RegraPuloDialog> {
  final service = PerguntasService();
  final valorResposta = TextEditingController();

  String? perguntaDestinoId;
  bool encerrarQuestionario = false;
  bool salvando = false;

  @override
  void dispose() {
    valorResposta.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get perguntasDestino {
    final origemId = widget.perguntaOrigem['id']?.toString();

    return widget.perguntas.where((p) {
      return p['id']?.toString() != origemId;
    }).toList();
  }

  Future<void> adicionarRegra() async {
    if (valorResposta.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor da resposta.')),
      );
      return;
    }

    if (!encerrarQuestionario &&
        (perguntaDestinoId == null || perguntaDestinoId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a pergunta destino.')),
      );
      return;
    }

    setState(() => salvando = true);

    try {
      await service.criarRegraPulo(
        perguntaOrigemId: widget.perguntaOrigem['id'].toString(),
        valorResposta: valorResposta.text.trim(),
        perguntaDestinoId: encerrarQuestionario ? null : perguntaDestinoId,
        encerrarQuestionario: encerrarQuestionario,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar regra: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> removerRegra(String id) async {
    await service.deletarRegraPulo(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String nomePergunta(Map<String, dynamic> p) {
    final codigo = (p['codigo'] ?? '').toString();
    final texto = (p['texto'] ?? '').toString();

    if (codigo.isNotEmpty) return '$codigo - $texto';
    return texto;
  }

  String nomePerguntaPorId(dynamic id) {
    if (id == null) return '-';

    final p = widget.perguntas.where((x) {
      return x['id']?.toString() == id.toString();
    }).firstOrNull;

    return p == null ? '-' : nomePergunta(p);
  }

  @override
  Widget build(BuildContext context) {
    final perguntaTexto = nomePergunta(widget.perguntaOrigem);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Regras de pulo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  perguntaTexto,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                if (widget.regras.isNotEmpty) ...[
                  const Text(
                    'Regras cadastradas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...widget.regras.map((r) {
                    final encerrar = r['encerrar_questionario'] == true;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Se resposta = "${r['valor_resposta']}"',
                      ),
                      subtitle: Text(
                        encerrar
                            ? 'Encerrar questionário'
                            : 'Ir para: ${nomePerguntaPorId(r['pergunta_destino_id'])}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => removerRegra(r['id'].toString()),
                      ),
                    );
                  }),
                  const Divider(height: 32),
                ],
                const Text(
                  'Nova regra',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorResposta,
                  decoration: const InputDecoration(
                    labelText: 'Valor da resposta',
                    hintText: 'Ex: Sim, Não, 1, 2, 3...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: encerrarQuestionario,
                  title: const Text('Encerrar questionário nesta resposta'),
                  onChanged: (v) {
                    setState(() {
                      encerrarQuestionario = v;
                      if (encerrarQuestionario) perguntaDestinoId = null;
                    });
                  },
                ),
                if (!encerrarQuestionario) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: perguntaDestinoId,
                    decoration: const InputDecoration(
                      labelText: 'Pergunta destino',
                      border: OutlineInputBorder(),
                    ),
                    items: perguntasDestino.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(nomePergunta(p)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => perguntaDestinoId = v),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: salvando ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: salvando ? null : adicionarRegra,
                      child: salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Adicionar regra'),
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