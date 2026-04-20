import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/clientes_service.dart';
import '../services/pesquisas_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class PesquisasPage extends StatefulWidget {
  const PesquisasPage({super.key});

  @override
  State<PesquisasPage> createState() => _PesquisasPageState();
}

class _PesquisasPageState extends State<PesquisasPage> {
  final _pesquisasService = PesquisasService();
  final _profileService = ProfileService();
  final _searchController = TextEditingController();

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> pesquisas = [];
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
      final lista = await _pesquisasService.listarPesquisas();

      if (!mounted) return;

      setState(() {
        profile = perfil;
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

  List<Map<String, dynamic>> get pesquisasFiltradas {
    final q = _searchController.text.trim().toLowerCase();

    if (q.isEmpty) return pesquisas;

    return pesquisas.where((p) {
      final titulo = (p['titulo'] ?? '').toString().toLowerCase();
      final status = (p['status'] ?? '').toString().toLowerCase();
      final cliente = ((p['clientes']?['nome']) ?? '').toString().toLowerCase();

      return titulo.contains(q) || status.contains(q) || cliente.contains(q);
    }).toList();
  }

  int get totalPlanejadas =>
      pesquisas.where((p) => p['status'] == 'planejada').length;

  int get totalAndamento =>
      pesquisas.where((p) => p['status'] == 'em_andamento').length;

  int get totalConcluidas =>
      pesquisas.where((p) => p['status'] == 'concluida').length;

  int get totalPausadas =>
      pesquisas.where((p) => p['status'] == 'pausada').length;

  Future<void> abrirFormulario({Map<String, dynamic>? pesquisa}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PesquisaFormDialog(pesquisa: pesquisa),
    );

    if (result == true) {
      await carregarTudo();
    }
  }

  Future<void> excluirPesquisa(Map<String, dynamic> p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir pesquisa'),
        content: Text(
          'Deseja realmente excluir a pesquisa "${p['titulo'] ?? ''}"?',
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

    await _pesquisasService.softDeletePesquisa(p['id'].toString());
    await carregarTudo();
  }

  String formatarData(dynamic valor) {
    if (valor == null) return '-';

    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return '-';

    return DateFormat('dd/MM/yyyy').format(dt);
  }

  Widget _buildResumoCard({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
    return Container(
      width: 240,
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

  Widget _buildStatusChip(String status) {
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
      case 'pausada':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'Pausada';
        break;
      case 'cancelada':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Cancelada';
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
        label = status;
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

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? 'Usuário').toString();
    final tipo = (profile?['tipo'] ?? '').toString();

    return AdminShell(
      title: 'Pesquisas',
      userName: nome,
      userType: tipo,
      selectedIndex: 3,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestão de pesquisas',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de pesquisas: ${pesquisas.length}',
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
                      titulo: 'Planejadas',
                      valor: totalPlanejadas.toString(),
                      icone: Icons.event_note_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Em andamento',
                      valor: totalAndamento.toString(),
                      icone: Icons.play_circle_outline_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Concluídas',
                      valor: totalConcluidas.toString(),
                      icone: Icons.check_circle_outline_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Pausadas',
                      valor: totalPausadas.toString(),
                      icone: Icons.pause_circle_outline_rounded,
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
                                    'Buscar por título, cliente ou status',
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
                            label: const Text('Nova pesquisa'),
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
                      if (pesquisasFiltradas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhuma pesquisa encontrada.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF3F4F6),
                            ),
                            columns: const [
                              DataColumn(label: Text('Título')),
                              DataColumn(label: Text('Cliente')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Início')),
                              DataColumn(label: Text('Fim')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: pesquisasFiltradas.map((p) {
                              final status =
                                  (p['status'] ?? '').toString();

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text((p['titulo'] ?? '').toString()),
                                  ),
                                  DataCell(
                                    Text(
                                      ((p['clientes']?['nome']) ?? '')
                                          .toString(),
                                    ),
                                  ),
                                  DataCell(_buildStatusChip(status)),
                                  DataCell(Text(formatarData(p['data_inicio']))),
                                  DataCell(Text(formatarData(p['data_fim']))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar',
                                          onPressed: () =>
                                              abrirFormulario(pesquisa: p),
                                          icon:
                                              const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Excluir',
                                          onPressed: () => excluirPesquisa(p),
                                          icon: const Icon(
                                            Icons.delete_outline,
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
    );
  }
}

class PesquisaFormDialog extends StatefulWidget {
  final Map<String, dynamic>? pesquisa;

  const PesquisaFormDialog({
    super.key,
    this.pesquisa,
  });

  @override
  State<PesquisaFormDialog> createState() => _PesquisaFormDialogState();
}

class _PesquisaFormDialogState extends State<PesquisaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = PesquisasService();
  final _clientesService = ClientesService();

  final tituloController = TextEditingController();
  final descricaoController = TextEditingController();
  final metaController = TextEditingController();
  final totalController = TextEditingController();
  final observacoesController = TextEditingController();

  List<Map<String, dynamic>> clientes = [];
  String? clienteId;
  String status = 'planejada';
  DateTime? dataInicio;
  DateTime? dataFim;
  bool loading = true;
  bool salvando = false;

  bool get editando => widget.pesquisa != null;

  @override
  void initState() {
    super.initState();

    tituloController.text = widget.pesquisa?['titulo']?.toString() ?? '';
    descricaoController.text =
        widget.pesquisa?['descricao']?.toString() ?? '';
    metaController.text =
        widget.pesquisa?['meta_respostas']?.toString() ?? '';
    totalController.text =
        widget.pesquisa?['total_esperado']?.toString() ?? '';
    observacoesController.text =
        widget.pesquisa?['observacoes']?.toString() ?? '';

    clienteId = widget.pesquisa?['cliente_id']?.toString();
    status = widget.pesquisa?['status']?.toString() ?? 'planejada';

    if (widget.pesquisa?['data_inicio'] != null) {
      dataInicio =
          DateTime.tryParse(widget.pesquisa!['data_inicio'].toString());
    }

    if (widget.pesquisa?['data_fim'] != null) {
      dataFim = DateTime.tryParse(widget.pesquisa!['data_fim'].toString());
    }

    carregarClientes();
  }

  @override
  void dispose() {
    tituloController.dispose();
    descricaoController.dispose();
    metaController.dispose();
    totalController.dispose();
    observacoesController.dispose();
    super.dispose();
  }

  Future<void> carregarClientes() async {
    final lista = await _clientesService.listarClientes();

    if (!mounted) return;

    setState(() {
      clientes = lista;
      loading = false;
    });
  }

  Future<void> selecionarDataInicio() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataInicio ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() => dataInicio = data);
    }
  }

  Future<void> selecionarDataFim() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataFim ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() => dataFim = data);
    }
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (clienteId == null || clienteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o cliente')),
      );
      return;
    }

    setState(() => salvando = true);

    try {
      if (editando) {
        await _service.atualizarPesquisa(
          id: widget.pesquisa!['id'].toString(),
          clienteId: clienteId!,
          titulo: tituloController.text,
          descricao: descricaoController.text,
          status: status,
          dataInicio: dataInicio,
          dataFim: dataFim,
          metaRespostas: int.tryParse(metaController.text),
          totalEsperado: int.tryParse(totalController.text),
          observacoes: observacoesController.text,
        );
      } else {
        await _service.criarPesquisa(
          clienteId: clienteId!,
          titulo: tituloController.text,
          descricao: descricaoController.text,
          status: status,
          dataInicio: dataInicio,
          dataFim: dataFim,
          metaRespostas: int.tryParse(metaController.text),
          totalEsperado: int.tryParse(totalController.text),
          observacoes: observacoesController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar pesquisa: $e')),
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
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editando ? 'Editar pesquisa' : 'Nova pesquisa',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: clienteId,
                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      border: OutlineInputBorder(),
                    ),
                    items: clientes.map((cliente) {
                      return DropdownMenuItem<String>(
                        value: cliente['id'].toString(),
                        child: Text((cliente['nome'] ?? '').toString()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => clienteId = value),
                    validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Selecione o cliente'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título da pesquisa',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o título';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descricaoController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'planejada',
                        child: Text('Planejada'),
                      ),
                      DropdownMenuItem(
                        value: 'em_andamento',
                        child: Text('Em andamento'),
                      ),
                      DropdownMenuItem(
                        value: 'pausada',
                        child: Text('Pausada'),
                      ),
                      DropdownMenuItem(
                        value: 'concluida',
                        child: Text('Concluída'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelada',
                        child: Text('Cancelada'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => status = value ?? 'planejada'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: selecionarDataInicio,
                          child: Text(
                            dataInicio == null
                                ? 'Selecionar início'
                                : 'Início: ${DateFormat('dd/MM/yyyy').format(dataInicio!)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: selecionarDataFim,
                          child: Text(
                            dataFim == null
                                ? 'Selecionar fim'
                                : 'Fim: ${DateFormat('dd/MM/yyyy').format(dataFim!)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: metaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Meta de respostas',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: totalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total esperado',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: observacoesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
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