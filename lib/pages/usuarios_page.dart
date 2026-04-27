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

  bool loading = true;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> clientes = [];

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

      final dataUsuarios = await supabase
          .from('profiles')
          .select('''
            id,
            nome,
            email,
            tipo,
            cpf,
            telefone_1,
            telefone_2,
            cep,
            endereco,
            numero,
            complemento,
            bairro,
            cidade,
            uf,
            ativo,
            created_at,
            deleted_at
          ''')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final dataClientes = await supabase
          .from('clientes')
          .select('id, nome, razao_social, nome_fantasia, status')
          .order('nome');

      if (!mounted) return;

      setState(() {
        profile = perfil;
        usuarios = List<Map<String, dynamic>>.from(dataUsuarios);
        clientes = List<Map<String, dynamic>>.from(dataClientes);
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
      final email = (u['email'] ?? '').toString().toLowerCase();
      final cpf = (u['cpf'] ?? '').toString().toLowerCase();
      final telefone1 = (u['telefone_1'] ?? '').toString().toLowerCase();
      final telefone2 = (u['telefone_2'] ?? '').toString().toLowerCase();
      final cidade = (u['cidade'] ?? '').toString().toLowerCase();
      final uf = (u['uf'] ?? '').toString().toLowerCase();

      final tipo = (u['tipo'] ?? '').toString();
      final ativo = u['ativo'] == true;

      final bateBusca = busca.isEmpty ||
          nome.contains(busca) ||
          email.contains(busca) ||
          cpf.contains(busca) ||
          telefone1.contains(busca) ||
          telefone2.contains(busca) ||
          cidade.contains(busca) ||
          uf.contains(busca);

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

  String cidadeUf(Map<String, dynamic> usuario) {
    final cidade = (usuario['cidade'] ?? '').toString();
    final uf = (usuario['uf'] ?? '').toString();

    if (cidade.isEmpty && uf.isEmpty) return '-';
    return '$cidade${uf.isNotEmpty ? '/$uf' : ''}';
  }

  String telefonePrincipal(Map<String, dynamic> usuario) {
    final t1 = (usuario['telefone_1'] ?? '').toString();
    final t2 = (usuario['telefone_2'] ?? '').toString();

    if (t1.isNotEmpty) return t1;
    if (t2.isNotEmpty) return t2;
    return '-';
  }

  Future<String?> buscarClienteVinculado(String userId) async {
    final vinculo = await supabase
        .from('usuarios_clientes')
        .select('cliente_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (vinculo == null) return null;
    return vinculo['cliente_id']?.toString();
  }

  Future<void> salvarVinculoCliente({
    required String userId,
    required String? clienteId,
  }) async {
    await supabase.from('usuarios_clientes').delete().eq('user_id', userId);

    if (clienteId == null || clienteId.isEmpty) return;

    await supabase.from('usuarios_clientes').insert({
      'user_id': userId,
      'cliente_id': clienteId,
      'role': 'cliente',
      'status': 'ativo',
    });
  }

  Future<void> novoUsuario() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsuarioFormDialog(
        clientes: clientes,
        onSalvar: ({
          required nome,
          required email,
          required tipo,
          required ativo,
          required cpf,
          required telefone1,
          required telefone2,
          required cep,
          required endereco,
          required numero,
          required complemento,
          required bairro,
          required cidade,
          required uf,
          required password,
          required clienteId,
        }) async {
          if (password == null || password.trim().isEmpty) {
            throw Exception('Informe a senha temporária.');
          }

          final body = <String, dynamic>{
            'nome': nome,
            'email': email,
            'password': password,
            'tipo': tipo,
            if (tipo == 'cliente') 'cliente_id': clienteId,
          };

          final response = await supabase.functions.invoke(
            'hyper-function',
            body: body,
          );

          final data = response.data;

          if (data is Map && data['error'] != null) {
            throw Exception(data['error']);
          }

          final userId = (data is Map ? data['user_id'] : null)?.toString();

          if (userId != null && userId.isNotEmpty) {
            await supabase.from('profiles').update({
              'cpf': _nullSeVazio(cpf),
              'telefone_1': _nullSeVazio(telefone1),
              'telefone_2': _nullSeVazio(telefone2),
              'cep': _nullSeVazio(cep),
              'endereco': _nullSeVazio(endereco),
              'numero': _nullSeVazio(numero),
              'complemento': _nullSeVazio(complemento),
              'bairro': _nullSeVazio(bairro),
              'cidade': _nullSeVazio(cidade),
              'uf': _nullSeVazio(uf.toUpperCase()),
              'ativo': ativo,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
          }

          await carregarTudo();
        },
      ),
    );
  }

  Future<void> editarUsuario(Map<String, dynamic> usuario) async {
    final clienteVinculado = usuario['tipo'] == 'cliente'
        ? await buscarClienteVinculado(usuario['id'].toString())
        : null;

    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsuarioFormDialog(
        usuario: usuario,
        clientes: clientes,
        clienteVinculadoId: clienteVinculado,
        onSalvar: ({
          required nome,
          required email,
          required tipo,
          required ativo,
          required cpf,
          required telefone1,
          required telefone2,
          required cep,
          required endereco,
          required numero,
          required complemento,
          required bairro,
          required cidade,
          required uf,
          required password,
          required clienteId,
        }) async {
          final userId = usuario['id'].toString();

          await supabase.from('profiles').update({
            'nome': nome.trim(),
            'email': _nullSeVazio(email),
            'tipo': tipo,
            'cpf': _nullSeVazio(cpf),
            'telefone_1': _nullSeVazio(telefone1),
            'telefone_2': _nullSeVazio(telefone2),
            'cep': _nullSeVazio(cep),
            'endereco': _nullSeVazio(endereco),
            'numero': _nullSeVazio(numero),
            'complemento': _nullSeVazio(complemento),
            'bairro': _nullSeVazio(bairro),
            'cidade': _nullSeVazio(cidade),
            'uf': _nullSeVazio(uf.toUpperCase()),
            'ativo': ativo,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);

          if (tipo == 'cliente') {
            await salvarVinculoCliente(
              userId: userId,
              clienteId: clienteId,
            );
          } else {
            await salvarVinculoCliente(
              userId: userId,
              clienteId: null,
            );
          }

          await carregarTudo();
        },
      ),
    );
  }

  Future<void> alternarStatus(Map<String, dynamic> usuario) async {
    final ativoAtual = usuario['ativo'] == true;

    await supabase.from('profiles').update({
      'ativo': !ativoAtual,
      'updated_at': DateTime.now().toIso8601String(),
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
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', usuario['id']);

    await carregarTudo();
  }

  String? _nullSeVazio(String? valor) {
    if (valor == null) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
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
                          hintText:
                              'Pesquisar por nome, e-mail, CPF, telefone ou cidade',
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
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Tipo')),
                              DataColumn(label: Text('CPF')),
                              DataColumn(label: Text('Telefone')),
                              DataColumn(label: Text('Cidade/UF')),
                              DataColumn(label: Text('Status')),
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
                                    Text(usuario['email']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    _TipoBadge(
                                      tipo: usuario['tipo']?.toString() ?? '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(usuario['cpf']?.toString() ?? '-'),
                                  ),
                                  DataCell(Text(telefonePrincipal(usuario))),
                                  DataCell(Text(cidadeUf(usuario))),
                                  DataCell(_StatusBadge(ativo: ativo)),
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

typedef UsuarioSalvarCallback = Future<void> Function({
  required String nome,
  required String email,
  required String tipo,
  required bool ativo,
  required String cpf,
  required String telefone1,
  required String telefone2,
  required String cep,
  required String endereco,
  required String numero,
  required String complemento,
  required String bairro,
  required String cidade,
  required String uf,
  required String? password,
  required String? clienteId,
});

class UsuarioFormDialog extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  final List<Map<String, dynamic>> clientes;
  final String? clienteVinculadoId;
  final UsuarioSalvarCallback onSalvar;

  const UsuarioFormDialog({
    super.key,
    this.usuario,
    required this.clientes,
    this.clienteVinculadoId,
    required this.onSalvar,
  });

  @override
  State<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nomeController;
  late final TextEditingController emailController;
  late final TextEditingController senhaController;
  late final TextEditingController cpfController;
  late final TextEditingController telefone1Controller;
  late final TextEditingController telefone2Controller;
  late final TextEditingController cepController;
  late final TextEditingController enderecoController;
  late final TextEditingController numeroController;
  late final TextEditingController complementoController;
  late final TextEditingController bairroController;
  late final TextEditingController cidadeController;
  late final TextEditingController ufController;

  String tipo = 'colaborador';
  String? clienteId;
  bool ativo = true;
  bool salvando = false;

  bool get editando => widget.usuario != null;

  @override
  void initState() {
    super.initState();

    final u = widget.usuario;

    nomeController =
        TextEditingController(text: u?['nome']?.toString() ?? '');
    emailController =
        TextEditingController(text: u?['email']?.toString() ?? '');
    senhaController = TextEditingController();
    cpfController = TextEditingController(text: u?['cpf']?.toString() ?? '');
    telefone1Controller =
        TextEditingController(text: u?['telefone_1']?.toString() ?? '');
    telefone2Controller =
        TextEditingController(text: u?['telefone_2']?.toString() ?? '');
    cepController = TextEditingController(text: u?['cep']?.toString() ?? '');
    enderecoController =
        TextEditingController(text: u?['endereco']?.toString() ?? '');
    numeroController =
        TextEditingController(text: u?['numero']?.toString() ?? '');
    complementoController =
        TextEditingController(text: u?['complemento']?.toString() ?? '');
    bairroController =
        TextEditingController(text: u?['bairro']?.toString() ?? '');
    cidadeController =
        TextEditingController(text: u?['cidade']?.toString() ?? '');
    ufController = TextEditingController(text: u?['uf']?.toString() ?? '');

    tipo = u?['tipo']?.toString() ?? 'colaborador';
    ativo = u?['ativo'] == true || u == null;
    clienteId = widget.clienteVinculadoId;
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    cpfController.dispose();
    telefone1Controller.dispose();
    telefone2Controller.dispose();
    cepController.dispose();
    enderecoController.dispose();
    numeroController.dispose();
    complementoController.dispose();
    bairroController.dispose();
    cidadeController.dispose();
    ufController.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (tipo == 'cliente' && (clienteId == null || clienteId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o cliente vinculado.')),
      );
      return;
    }

    setState(() => salvando = true);

    try {
      await widget.onSalvar(
        nome: nomeController.text.trim(),
        email: emailController.text.trim(),
        tipo: tipo,
        ativo: ativo,
        cpf: cpfController.text.trim(),
        telefone1: telefone1Controller.text.trim(),
        telefone2: telefone2Controller.text.trim(),
        cep: cepController.text.trim(),
        endereco: enderecoController.text.trim(),
        numero: numeroController.text.trim(),
        complemento: complementoController.text.trim(),
        bairro: bairroController.text.trim(),
        cidade: cidadeController.text.trim(),
        uf: ufController.text.trim(),
        password: editando ? null : senhaController.text.trim(),
        clienteId: tipo == 'cliente' ? clienteId : null,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editando
                ? 'Usuário atualizado com sucesso.'
                : 'Usuário criado com sucesso.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar usuário: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Widget campoTexto({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
                    editando ? 'Editar usuário' : 'Novo usuário',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  tituloSecao('Dados principais'),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: campoTexto(
                          controller: nomeController,
                          label: 'Nome',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: campoTexto(
                          controller: cpfController,
                          label: 'CPF',
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o e-mail';
                            }
                            if (!value.contains('@')) {
                              return 'E-mail inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (!editando) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: campoTexto(
                            controller: senhaController,
                            label: 'Senha temporária',
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
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
                            if (value == null) return;

                            setState(() {
                              tipo = value;
                              if (tipo != 'cliente') {
                                clienteId = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Usuário ativo'),
                          value: ativo,
                          onChanged: (value) {
                            setState(() => ativo = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (tipo == 'cliente') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: clienteId,
                      decoration: const InputDecoration(
                        labelText: 'Cliente vinculado',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.clientes.map((cliente) {
                        final nome =
                            (cliente['nome'] ?? '').toString();
                        final fantasia =
                            (cliente['nome_fantasia'] ?? '').toString();
                        final label = fantasia.isNotEmpty
                            ? '$nome - $fantasia'
                            : nome;

                        return DropdownMenuItem<String>(
                          value: cliente['id'].toString(),
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => clienteId = value);
                      },
                      validator: (value) {
                        if (tipo == 'cliente' &&
                            (value == null || value.isEmpty)) {
                          return 'Selecione o cliente';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  tituloSecao('Contato'),
                  Row(
                    children: [
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