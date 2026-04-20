import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/questionarios_service.dart';
import '../services/pesquisas_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class QuestionariosPage extends StatefulWidget {
  const QuestionariosPage({super.key});

  @override
  State<QuestionariosPage> createState() => _QuestionariosPageState();
}

class _QuestionariosPageState extends State<QuestionariosPage> {
  final QuestionariosService service = QuestionariosService();
  final PesquisasService pesquisasService = PesquisasService();
  final ProfileService profileService = ProfileService();

  List<Map<String, dynamic>> lista = [];
  Map<String, dynamic>? profile;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    carregar();
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

  Future<void> excluir(String id) async {
    await service.deletar(id);
    await carregar();
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
                ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const QuestionarioDialog(),
                    );

                    if (result == true) {
                      await carregar();
                    }
                  },
                  child: const Text('Novo Questionário'),
                ),
                const SizedBox(height: 20),
                if (lista.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhum questionário encontrado.'),
                    ),
                  )
                else
                  Column(
                    children: lista.map((q) {
                      final questionarioId = (q['id'] ?? '').toString();
                      final questionarioTitulo =
                          (q['titulo'] ?? '').toString();
                      final pesquisaTitulo =
                          ((q['pesquisas']?['titulo']) ?? '').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(questionarioTitulo),
                          subtitle: Text(pesquisaTitulo),
                          onTap: () {
                            context.go(
                              '/perguntas/$questionarioId',
                              extra: {
                                'titulo': questionarioTitulo,
                                'pesquisaTitulo': pesquisaTitulo,
                              },
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete),
                                onPressed: () => excluir(questionarioId),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
    );
  }
}

class QuestionarioDialog extends StatefulWidget {
  const QuestionarioDialog({super.key});

  @override
  State<QuestionarioDialog> createState() => _QuestionarioDialogState();
}

class _QuestionarioDialogState extends State<QuestionarioDialog> {
  final QuestionariosService service = QuestionariosService();
  final PesquisasService pesquisasService = PesquisasService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController titulo = TextEditingController();
  final TextEditingController descricao = TextEditingController();

  List<Map<String, dynamic>> pesquisas = [];
  String? pesquisaId;
  bool loading = true;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregarPesquisas();
  }

  @override
  void dispose() {
    titulo.dispose();
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
      await service.criar(
        pesquisaId: pesquisaId!,
        titulo: titulo.text.trim(),
        descricao: descricao.text.trim(),
      );

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
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Novo Questionário',
                  style: TextStyle(
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