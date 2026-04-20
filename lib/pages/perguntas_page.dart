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
  final String pesquisaTitulo; // 👈 ADICIONE

  const PerguntasPage({
    super.key,
    required this.questionarioId,
    required this.questionarioTitulo,
    required this.pesquisaTitulo, // 👈 ADICIONE
  });

  @override
  State<PerguntasPage> createState() => _PerguntasPageState();
}

class _PerguntasPageState extends State<PerguntasPage> {
  final PerguntasService service = PerguntasService();
  final ProfileService profileService = ProfileService();
  final ImportExcelService importService = ImportExcelService();

  List<Map<String, dynamic>> perguntas = [];
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
      final lista = await service.listar(widget.questionarioId);
      final perfil = await profileService.getProfile();

      if (!mounted) return;

      setState(() {
        perguntas = lista;
        profile = perfil;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perguntas: $e')),
      );
    }
  }

  Future<void> excluir(String id) async {
    await service.deletar(id);
    await carregar();
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
      if (mounted) {
        setState(() => importing = false);
      }
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
      if (mounted) {
        setState(() => downloading = false);
      }
    }
  }

  String traduzirTipo(String tipo) {
    switch (tipo) {
      case 'texto':
        return 'Texto';
      case 'numero':
        return 'Número';
      case 'unica':
        return 'Escolha única';
      case 'multipla':
        return 'Múltipla escolha';
      case 'booleano':
        return 'Sim/Não';
      case 'escala':
        return 'Escala';
      default:
        return tipo;
    }
  }

  Widget _buildTipoChip(String tipo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        traduzirTipo(tipo),
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildObrigatoriaChip(bool obrigatoria) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: obrigatoria
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        obrigatoria ? 'Obrigatória' : 'Opcional',
        style: TextStyle(
          color: obrigatoria
              ? const Color(0xFF991B1B)
              : const Color(0xFF374151),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildClassificatoriaChip(bool classificatoria) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: classificatoria
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        classificatoria ? 'Classificatória' : 'Comum',
        style: TextStyle(
          color: classificatoria
              ? const Color(0xFFB45309)
              : const Color(0xFF374151),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String formatarOpcoes(dynamic opcoes) {
    if (opcoes == null) return '-';

    if (opcoes is List) {
      return opcoes.join(', ');
    }

    final texto = opcoes.toString();
    return texto.isEmpty ? '-' : texto;
  }

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? '').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    return AdminShell(
      title: 'Perguntas',
      userName: nome,
      userType: tipo,
      selectedIndex: 5,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                            'Perguntas do questionário: ${widget.questionarioTitulo}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total de perguntas: ${perguntas.length}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => PerguntaDialog(
                                  questionarioId: widget.questionarioId,
                                ),
                              );

                              if (result == true) {
                                await carregar();
                              }
                            },
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
                      const SizedBox(height: 20),
                      if (perguntas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhuma pergunta encontrada.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              const Color(0xFFF3F4F6),
                            ),
                            columns: const [
                              DataColumn(label: Text('Ordem')),
                              DataColumn(label: Text('Código')),
                              DataColumn(label: Text('Pergunta')),
                              DataColumn(label: Text('Tipo')),
                              DataColumn(label: Text('Obrigatória')),
                              DataColumn(label: Text('Classificação')),
                              DataColumn(label: Text('Opções')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: perguntas.map((p) {
                              final texto = (p['texto'] ?? '').toString();
                              final tipoPergunta =
                                  (p['tipo'] ?? '').toString();
                              final obrigatoria =
                                  (p['obrigatoria'] ?? false) == true;
                              final classificatoria =
                                  (p['classificatoria'] ?? false) == true;
                              final ordem = p['ordem']?.toString() ?? '-';
                              final codigo = p['codigo']?.toString() ?? '-';

                              return DataRow(
                                cells: [
                                  DataCell(Text(ordem)),
                                  DataCell(Text(codigo)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 320,
                                      ),
                                      child: Text(texto),
                                    ),
                                  ),
                                  DataCell(_buildTipoChip(tipoPergunta)),
                                  DataCell(
                                    _buildObrigatoriaChip(obrigatoria),
                                  ),
                                  DataCell(
                                    _buildClassificatoriaChip(
                                      classificatoria,
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      child: Text(formatarOpcoes(p['opcoes'])),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Excluir',
                                      icon:
                                          const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          excluir(p['id'].toString()),
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

class PerguntaDialog extends StatefulWidget {
  final String questionarioId;

  const PerguntaDialog({
    super.key,
    required this.questionarioId,
  });

  @override
  State<PerguntaDialog> createState() => _PerguntaDialogState();
}

class _PerguntaDialogState extends State<PerguntaDialog> {
  final PerguntasService service = PerguntasService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController texto = TextEditingController();
  final TextEditingController opcoes = TextEditingController();
  final TextEditingController ordem = TextEditingController(text: '1');
  final TextEditingController codigo = TextEditingController();

  String tipo = 'texto';
  bool obrigatoria = false;
  bool classificatoria = false;
  bool salvando = false;

  @override
  void dispose() {
    texto.dispose();
    opcoes.dispose();
    ordem.dispose();
    codigo.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => salvando = true);

    try {
      await service.criar(
        questionarioId: widget.questionarioId,
        texto: texto.text.trim(),
        tipo: tipo,
        ordem: int.tryParse(ordem.text.trim()) ?? 1,
        obrigatoria: obrigatoria,
        classificatoria: classificatoria,
        codigo: codigo.text.trim(),
        opcoes: tipo == 'multipla' || tipo == 'unica' || tipo == 'escala'
            ? opcoes.text
                .split('|')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar pergunta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nova pergunta',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codigo,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o código da pergunta'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: texto,
                    decoration: const InputDecoration(
                      labelText: 'Pergunta',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o texto da pergunta'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    items: const [
                      DropdownMenuItem(
                        value: 'texto',
                        child: Text('Texto'),
                      ),
                      DropdownMenuItem(
                        value: 'numero',
                        child: Text('Número'),
                      ),
                      DropdownMenuItem(
                        value: 'unica',
                        child: Text('Escolha única'),
                      ),
                      DropdownMenuItem(
                        value: 'multipla',
                        child: Text('Múltipla escolha'),
                      ),
                      DropdownMenuItem(
                        value: 'booleano',
                        child: Text('Sim/Não'),
                      ),
                      DropdownMenuItem(
                        value: 'escala',
                        child: Text('Escala'),
                      ),
                    ],
                    onChanged: (v) => setState(() => tipo = v.toString()),
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
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
                  if (tipo == 'multipla' ||
                      tipo == 'unica' ||
                      tipo == 'escala') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: opcoes,
                      decoration: const InputDecoration(
                        labelText: 'Opções (separadas por | )',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((tipo == 'multipla' ||
                                tipo == 'unica' ||
                                tipo == 'escala') &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Informe as opções da pergunta';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: obrigatoria,
                    onChanged: (v) =>
                        setState(() => obrigatoria = v ?? false),
                    title: const Text('Obrigatória'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: classificatoria,
                    onChanged: (v) =>
                        setState(() => classificatoria = v ?? false),
                    title: const Text('Classificatória'),
                    contentPadding: EdgeInsets.zero,
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
                      ElevatedButton(
                        onPressed: salvando ? null : salvar,
                        child: salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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