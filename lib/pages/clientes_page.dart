import 'package:flutter/material.dart';

import '../services/client_access_service.dart';
import '../services/clientes_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin_shell.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ClientesService _clientesService = ClientesService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> clientes = [];
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

  Future<void> abrirCriarAcesso(Map<String, dynamic> cliente) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CriarAcessoClienteDialog(cliente: cliente),
    );
  }

  Future<void> carregarTudo() async {
    setState(() => loading = true);

    try {
      final perfil = await _profileService.getProfile();

      if (!mounted) return;
      setState(() {
        profile = perfil;
      });

      final lista = await _clientesService.listarClientes();

      if (!mounted) return;
      setState(() {
        clientes = lista;
        loading = false;
      });
    } catch (e, s) {
      debugPrint('ERRO AO CARREGAR CLIENTES PAGE: $e');
      debugPrintStack(stackTrace: s);

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar clientes: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get clientesFiltrados {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return clientes;

    return clientes.where((c) {
      final nome = (c['nome'] ?? '').toString().toLowerCase();
      final razaoSocial = (c['razao_social'] ?? '').toString().toLowerCase();
      final nomeFantasia = (c['nome_fantasia'] ?? '').toString().toLowerCase();
      final cpf = (c['cpf'] ?? '').toString().toLowerCase();
      final cnpj = (c['cnpj'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final plano = (c['plano'] ?? '').toString().toLowerCase();
      final responsavel =
          (c['responsavel_nome'] ?? '').toString().toLowerCase();
      final telefone1 = (c['telefone_1'] ?? '').toString().toLowerCase();
      final telefone2 = (c['telefone_2'] ?? '').toString().toLowerCase();
      final cidade = (c['cidade'] ?? '').toString().toLowerCase();
      final statusCliente = (c['status'] ?? '').toString().toLowerCase();
      final statusPesquisa = _textoResumoStatusPesquisa(c).toLowerCase();

      return nome.contains(query) ||
          razaoSocial.contains(query) ||
          nomeFantasia.contains(query) ||
          cpf.contains(query) ||
          cnpj.contains(query) ||
          email.contains(query) ||
          plano.contains(query) ||
          responsavel.contains(query) ||
          telefone1.contains(query) ||
          telefone2.contains(query) ||
          cidade.contains(query) ||
          statusCliente.contains(query) ||
          statusPesquisa.contains(query);
    }).toList();
  }

  Future<void> abrirFormulario({Map<String, dynamic>? cliente}) async {
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClienteFormDialog(cliente: cliente),
    );

    if (salvou == true) {
      await carregarTudo();
    }
  }

  Future<void> trocarStatus(Map<String, dynamic> cliente) async {
    final statusAtual = (cliente['status'] ?? 'ativo').toString();
    final novoStatus = statusAtual == 'ativo' ? 'inativo' : 'ativo';

    await _clientesService.alterarStatus(
      id: cliente['id'].toString(),
      status: novoStatus,
    );

    await carregarTudo();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  int get totalClientes => clientes.length;

  int get totalClientesAtivos =>
      clientes.where((c) => (c['status'] ?? '').toString() == 'ativo').length;

  int get totalClientesInativosOuBloqueados =>
      clientes.where((c) => (c['status'] ?? '').toString() != 'ativo').length;

  int get totalClientesComPesquisaAtiva =>
      clientes.where((c) => _toInt(c['pesquisas_ativas']) > 0).length;

  String documentoCliente(Map<String, dynamic> cliente) {
    final cnpj = (cliente['cnpj'] ?? '').toString();
    final cpf = (cliente['cpf'] ?? '').toString();

    if (cnpj.isNotEmpty) return cnpj;
    if (cpf.isNotEmpty) return cpf;
    return '-';
  }

  String telefoneCliente(Map<String, dynamic> cliente) {
    final telefone1 = (cliente['telefone_1'] ?? '').toString();
    final telefoneAntigo = (cliente['telefone'] ?? '').toString();

    if (telefone1.isNotEmpty) return telefone1;
    if (telefoneAntigo.isNotEmpty) return telefoneAntigo;
    return '-';
  }

  String _textoResumoStatusPesquisa(Map<String, dynamic> cliente) {
    final total = _toInt(cliente['total_pesquisas']);
    final ativas = _toInt(cliente['pesquisas_ativas']);
    final concluidas = _toInt(cliente['pesquisas_concluidas']);
    final pausadas = _toInt(cliente['pesquisas_pausadas']);
    final canceladas = _toInt(cliente['pesquisas_canceladas']);

    if (total == 0) return 'Sem pesquisas';
    if (ativas > 0 && concluidas == 0 && pausadas == 0 && canceladas == 0) {
      return 'Ativa';
    }
    if (ativas > 0) return 'Mista';
    if (pausadas > 0 && concluidas == 0 && canceladas == 0) {
      return 'Pausada';
    }
    if (canceladas > 0 && concluidas == 0 && pausadas == 0) {
      return 'Cancelada';
    }
    if (concluidas > 0 && ativas == 0 && pausadas == 0 && canceladas == 0) {
      return 'Concluída';
    }
    return 'Mista';
  }

  Widget _buildClienteStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'ativo':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Ativo';
        break;
      case 'bloqueado':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Bloqueado';
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
        label = 'Inativo';
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
        ),
      ),
    );
  }

  Widget _buildPesquisaStatusChip(Map<String, dynamic> cliente) {
    final resumo = _textoResumoStatusPesquisa(cliente);

    Color bg;
    Color fg;

    switch (resumo) {
      case 'Ativa':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'Concluída':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'Pausada':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case 'Cancelada':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'Sem pesquisas':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        resumo,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final nome = (profile?['nome'] ?? 'Usuário').toString();
    final tipo = (profile?['tipo'] ?? 'Sem perfil').toString();

    return AdminShell(
      title: 'Clientes',
      userName: nome,
      userType: tipo,
      selectedIndex: 2,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestão de clientes',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de clientes: $totalClientes',
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
                      titulo: 'Total',
                      valor: totalClientes.toString(),
                      icone: Icons.business_rounded,
                    ),
                    _buildResumoCard(
                      titulo: 'Ativos',
                      valor: totalClientesAtivos.toString(),
                      icone: Icons.verified_user_outlined,
                    ),
                    _buildResumoCard(
                      titulo: 'Inativos/Bloqueados',
                      valor: totalClientesInativosOuBloqueados.toString(),
                      icone: Icons.block_outlined,
                    ),
                    _buildResumoCard(
                      titulo: 'Com pesquisa ativa',
                      valor: totalClientesComPesquisaAtiva.toString(),
                      icone: Icons.assignment_turned_in_outlined,
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
                                    'Buscar por nome, documento, e-mail, telefone, cidade, plano ou responsável',
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
                            label: const Text('Novo cliente'),
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
                      if (clientesFiltrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhum cliente encontrado.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF3F4F6),
                            ),
                            columns: const [
                              DataColumn(label: Text('Nome')),
                              DataColumn(label: Text('Documento')),
                              DataColumn(label: Text('Responsável')),
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Telefone')),
                              DataColumn(label: Text('Cidade/UF')),
                              DataColumn(label: Text('Plano')),
                              DataColumn(label: Text('Status cliente')),
                              DataColumn(label: Text('Status pesquisas')),
                              DataColumn(label: Text('Qtd pesquisas')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: clientesFiltrados.map((cliente) {
                              final status =
                                  (cliente['status'] ?? 'ativo').toString();
                              final totalPesquisas =
                                  _toInt(cliente['total_pesquisas']);
                              final cidade = (cliente['cidade'] ?? '').toString();
                              final uf = (cliente['uf'] ?? '').toString();
                              final cidadeUf = cidade.isEmpty && uf.isEmpty
                                  ? '-'
                                  : '$cidade${uf.isNotEmpty ? '/$uf' : ''}';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text((cliente['nome'] ?? '').toString()),
                                  ),
                                  DataCell(Text(documentoCliente(cliente))),
                                  DataCell(
                                    Text(
                                      (cliente['responsavel_nome'] ?? '')
                                          .toString(),
                                    ),
                                  ),
                                  DataCell(
                                    Text((cliente['email'] ?? '').toString()),
                                  ),
                                  DataCell(Text(telefoneCliente(cliente))),
                                  DataCell(Text(cidadeUf)),
                                  DataCell(
                                    Text((cliente['plano'] ?? '').toString()),
                                  ),
                                  DataCell(_buildClienteStatusChip(status)),
                                  DataCell(_buildPesquisaStatusChip(cliente)),
                                  DataCell(Text(totalPesquisas.toString())),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Criar acesso',
                                          onPressed: () =>
                                              abrirCriarAcesso(cliente),
                                          icon: const Icon(
                                            Icons.person_add_alt_1_outlined,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Editar',
                                          onPressed: () =>
                                              abrirFormulario(cliente: cliente),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: status == 'ativo'
                                              ? 'Inativar'
                                              : 'Ativar',
                                          onPressed: () =>
                                              trocarStatus(cliente),
                                          icon: Icon(
                                            status == 'ativo'
                                                ? Icons.toggle_off_outlined
                                                : Icons.toggle_on_outlined,
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

class CriarAcessoClienteDialog extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const CriarAcessoClienteDialog({
    super.key,
    required this.cliente,
  });

  @override
  State<CriarAcessoClienteDialog> createState() =>
      _CriarAcessoClienteDialogState();
}

class _CriarAcessoClienteDialogState extends State<CriarAcessoClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = ClientAccessService();

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool salvando = false;

  @override
  void initState() {
    super.initState();

    nomeController.text =
        widget.cliente['responsavel_nome']?.toString() ?? '';
    emailController.text = widget.cliente['email']?.toString() ?? '';
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => salvando = true);

    try {
      await _service.criarAcessoCliente(
        clienteId: widget.cliente['id'].toString(),
        nome: nomeController.text.trim(),
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acesso criado com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar acesso: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Criar acesso do cliente',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${widget.cliente['nome'] ?? ''}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do usuário',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: senhaController,
                  decoration: const InputDecoration(
                    labelText: 'Senha temporária',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          salvando ? null : () => Navigator.pop(context),
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
                          : const Text('Criar acesso'),
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

class ClienteFormDialog extends StatefulWidget {
  final Map<String, dynamic>? cliente;

  const ClienteFormDialog({
    super.key,
    this.cliente,
  });

  @override
  State<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<ClienteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = ClientesService();

  late final TextEditingController nomeController;
  late final TextEditingController razaoSocialController;
  late final TextEditingController nomeFantasiaController;
  late final TextEditingController cpfController;
  late final TextEditingController cnpjController;
  late final TextEditingController planoController;
  late final TextEditingController emailController;
  late final TextEditingController telefone1Controller;
  late final TextEditingController telefone2Controller;
  late final TextEditingController responsavelController;
  late final TextEditingController responsavelCpfController;
  late final TextEditingController cepController;
  late final TextEditingController enderecoController;
  late final TextEditingController numeroController;
  late final TextEditingController complementoController;
  late final TextEditingController bairroController;
  late final TextEditingController cidadeController;
  late final TextEditingController ufController;
  late final TextEditingController observacoesController;

  String status = 'ativo';
  bool salvando = false;

  bool get editando => widget.cliente != null;

  @override
  void initState() {
    super.initState();

    nomeController =
        TextEditingController(text: widget.cliente?['nome']?.toString() ?? '');
    razaoSocialController = TextEditingController(
      text: widget.cliente?['razao_social']?.toString() ?? '',
    );
    nomeFantasiaController = TextEditingController(
      text: widget.cliente?['nome_fantasia']?.toString() ?? '',
    );
    cpfController =
        TextEditingController(text: widget.cliente?['cpf']?.toString() ?? '');
    cnpjController =
        TextEditingController(text: widget.cliente?['cnpj']?.toString() ?? '');
    planoController =
        TextEditingController(text: widget.cliente?['plano']?.toString() ?? '');
    emailController =
        TextEditingController(text: widget.cliente?['email']?.toString() ?? '');
    telefone1Controller = TextEditingController(
      text: widget.cliente?['telefone_1']?.toString() ??
          widget.cliente?['telefone']?.toString() ??
          '',
    );
    telefone2Controller = TextEditingController(
      text: widget.cliente?['telefone_2']?.toString() ?? '',
    );
    responsavelController = TextEditingController(
      text: widget.cliente?['responsavel_nome']?.toString() ?? '',
    );
    responsavelCpfController = TextEditingController(
      text: widget.cliente?['responsavel_cpf']?.toString() ?? '',
    );
    cepController =
        TextEditingController(text: widget.cliente?['cep']?.toString() ?? '');
    enderecoController = TextEditingController(
      text: widget.cliente?['endereco']?.toString() ?? '',
    );
    numeroController = TextEditingController(
      text: widget.cliente?['numero']?.toString() ?? '',
    );
    complementoController = TextEditingController(
      text: widget.cliente?['complemento']?.toString() ?? '',
    );
    bairroController = TextEditingController(
      text: widget.cliente?['bairro']?.toString() ?? '',
    );
    cidadeController = TextEditingController(
      text: widget.cliente?['cidade']?.toString() ?? '',
    );
    ufController =
        TextEditingController(text: widget.cliente?['uf']?.toString() ?? '');
    observacoesController = TextEditingController(
      text: widget.cliente?['observacoes']?.toString() ?? '',
    );

    status = widget.cliente?['status']?.toString() ?? 'ativo';
  }

  @override
  void dispose() {
    nomeController.dispose();
    razaoSocialController.dispose();
    nomeFantasiaController.dispose();
    cpfController.dispose();
    cnpjController.dispose();
    planoController.dispose();
    emailController.dispose();
    telefone1Controller.dispose();
    telefone2Controller.dispose();
    responsavelController.dispose();
    responsavelCpfController.dispose();
    cepController.dispose();
    enderecoController.dispose();
    numeroController.dispose();
    complementoController.dispose();
    bairroController.dispose();
    cidadeController.dispose();
    ufController.dispose();
    observacoesController.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => salvando = true);

    try {
      if (editando) {
        await _service.atualizarCliente(
          id: widget.cliente!['id'].toString(),
          nome: nomeController.text.trim(),
          razaoSocial: razaoSocialController.text.trim(),
          nomeFantasia: nomeFantasiaController.text.trim(),
          cpf: cpfController.text.trim(),
          cnpj: cnpjController.text.trim(),
          plano: planoController.text.trim(),
          email: emailController.text.trim(),
          telefone1: telefone1Controller.text.trim(),
          telefone2: telefone2Controller.text.trim(),
          responsavelNome: responsavelController.text.trim(),
          responsavelCpf: responsavelCpfController.text.trim(),
          cep: cepController.text.trim(),
          endereco: enderecoController.text.trim(),
          numero: numeroController.text.trim(),
          complemento: complementoController.text.trim(),
          bairro: bairroController.text.trim(),
          cidade: cidadeController.text.trim(),
          uf: ufController.text.trim().toUpperCase(),
          status: status,
          observacoes: observacoesController.text.trim(),
        );
      } else {
        await _service.criarCliente(
          nome: nomeController.text.trim(),
          razaoSocial: razaoSocialController.text.trim(),
          nomeFantasia: nomeFantasiaController.text.trim(),
          cpf: cpfController.text.trim(),
          cnpj: cnpjController.text.trim(),
          plano: planoController.text.trim(),
          email: emailController.text.trim(),
          telefone1: telefone1Controller.text.trim(),
          telefone2: telefone2Controller.text.trim(),
          responsavelNome: responsavelController.text.trim(),
          responsavelCpf: responsavelCpfController.text.trim(),
          cep: cepController.text.trim(),
          endereco: enderecoController.text.trim(),
          numero: numeroController.text.trim(),
          complemento: complementoController.text.trim(),
          bairro: bairroController.text.trim(),
          cidade: cidadeController.text.trim(),
          uf: ufController.text.trim().toUpperCase(),
          status: status,
          observacoes: observacoesController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar cliente: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  Widget campoTexto({
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

  Widget tituloSecao(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
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
                    editando ? 'Editar cliente' : 'Novo cliente',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  tituloSecao('Dados principais'),
                  campoTexto(
                    controller: nomeController,
                    label: 'Nome do cliente',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome do cliente';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: razaoSocialController,
                          label: 'Razão social',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: nomeFantasiaController,
                          label: 'Nome fantasia',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: cpfController,
                          label: 'CPF',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: cnpjController,
                          label: 'CNPJ',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: planoController,
                          label: 'Plano',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  tituloSecao('Responsável e contato'),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: responsavelController,
                          label: 'Responsável',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: responsavelCpfController,
                          label: 'CPF do responsável',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: emailController,
                          label: 'E-mail',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: telefone1Controller,
                          label: 'Telefone 1',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: telefone2Controller,
                          label: 'Telefone 2',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  tituloSecao('Endereço'),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: cepController,
                          label: 'CEP',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: campoTexto(
                          controller: enderecoController,
                          label: 'Endereço',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: numeroController,
                          label: 'Número',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: campoTexto(
                          controller: complementoController,
                          label: 'Complemento',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: bairroController,
                          label: 'Bairro',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: cidadeController,
                          label: 'Cidade',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: campoTexto(
                          controller: ufController,
                          label: 'UF',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  tituloSecao('Status e observações'),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                      DropdownMenuItem(
                        value: 'inativo',
                        child: Text('Inativo'),
                      ),
                      DropdownMenuItem(
                        value: 'bloqueado',
                        child: Text('Bloqueado'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        status = value ?? 'ativo';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  campoTexto(
                    controller: observacoesController,
                    label: 'Observações',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: salvando ? null : salvar,
                        child: salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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