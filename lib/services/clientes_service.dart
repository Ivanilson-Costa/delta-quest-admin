import 'package:supabase_flutter/supabase_flutter.dart';

class ClientesService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listarClientes() async {
    final clientesResponse = await client
        .from('clientes')
        .select()
        .order('created_at', ascending: false);

    final pesquisasResponse = await client
        .from('pesquisas')
        .select('id, cliente_id, status, deleted_at')
        .isFilter('deleted_at', null);

    final clientes = List<Map<String, dynamic>>.from(clientesResponse);
    final pesquisas = List<Map<String, dynamic>>.from(pesquisasResponse);

    final Map<String, List<Map<String, dynamic>>> pesquisasPorCliente = {};

    for (final pesquisa in pesquisas) {
      final clienteId = (pesquisa['cliente_id'] ?? '').toString();
      if (clienteId.isEmpty) continue;

      pesquisasPorCliente.putIfAbsent(clienteId, () => []);
      pesquisasPorCliente[clienteId]!.add(pesquisa);
    }

    return clientes.map((cliente) {
      final clienteId = (cliente['id'] ?? '').toString();
      final pesquisasDoCliente = pesquisasPorCliente[clienteId] ?? [];

      return {
        ...cliente,
        'total_pesquisas': pesquisasDoCliente.length,
        'pesquisas_ativas': pesquisasDoCliente.where((p) {
          final status = (p['status'] ?? '').toString();
          return status == 'em_andamento' || status == 'planejada';
        }).length,
        'pesquisas_concluidas': pesquisasDoCliente.where((p) {
          return (p['status'] ?? '').toString() == 'concluida';
        }).length,
        'pesquisas_pausadas': pesquisasDoCliente.where((p) {
          return (p['status'] ?? '').toString() == 'pausada';
        }).length,
        'pesquisas_canceladas': pesquisasDoCliente.where((p) {
          return (p['status'] ?? '').toString() == 'cancelada';
        }).length,
      };
    }).toList();
  }

  Future<void> criarCliente({
    required String nome,
    String? razaoSocial,
    String? nomeFantasia,
    String? cpf,
    String? cnpj,
    String? plano,
    String? email,
    String? telefone1,
    String? telefone2,
    String? responsavelNome,
    String? responsavelCpf,
    String? cep,
    String? endereco,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? uf,
    String status = 'ativo',
    String? observacoes,
  }) async {
    await client.from('clientes').insert({
      'nome': nome.trim(),
      'razao_social': _nullSeVazio(razaoSocial),
      'nome_fantasia': _nullSeVazio(nomeFantasia),
      'cpf': _nullSeVazio(cpf),
      'cnpj': _nullSeVazio(cnpj),
      'plano': _nullSeVazio(plano),
      'email': _nullSeVazio(email),
      'telefone_1': _nullSeVazio(telefone1),
      'telefone_2': _nullSeVazio(telefone2),
      'responsavel_nome': _nullSeVazio(responsavelNome),
      'responsavel_cpf': _nullSeVazio(responsavelCpf),
      'cep': _nullSeVazio(cep),
      'endereco': _nullSeVazio(endereco),
      'numero': _nullSeVazio(numero),
      'complemento': _nullSeVazio(complemento),
      'bairro': _nullSeVazio(bairro),
      'cidade': _nullSeVazio(cidade),
      'uf': _nullSeVazio(uf?.toUpperCase()),
      'status': status,
      'observacoes': _nullSeVazio(observacoes),
    });
  }

  Future<void> atualizarCliente({
    required String id,
    required String nome,
    String? razaoSocial,
    String? nomeFantasia,
    String? cpf,
    String? cnpj,
    String? plano,
    String? email,
    String? telefone1,
    String? telefone2,
    String? responsavelNome,
    String? responsavelCpf,
    String? cep,
    String? endereco,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? uf,
    required String status,
    String? observacoes,
  }) async {
    await client.from('clientes').update({
      'nome': nome.trim(),
      'razao_social': _nullSeVazio(razaoSocial),
      'nome_fantasia': _nullSeVazio(nomeFantasia),
      'cpf': _nullSeVazio(cpf),
      'cnpj': _nullSeVazio(cnpj),
      'plano': _nullSeVazio(plano),
      'email': _nullSeVazio(email),
      'telefone_1': _nullSeVazio(telefone1),
      'telefone_2': _nullSeVazio(telefone2),
      'responsavel_nome': _nullSeVazio(responsavelNome),
      'responsavel_cpf': _nullSeVazio(responsavelCpf),
      'cep': _nullSeVazio(cep),
      'endereco': _nullSeVazio(endereco),
      'numero': _nullSeVazio(numero),
      'complemento': _nullSeVazio(complemento),
      'bairro': _nullSeVazio(bairro),
      'cidade': _nullSeVazio(cidade),
      'uf': _nullSeVazio(uf?.toUpperCase()),
      'status': status,
      'observacoes': _nullSeVazio(observacoes),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> alterarStatus({
    required String id,
    required String status,
  }) async {
    await client.from('clientes').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  String? _nullSeVazio(String? valor) {
    if (valor == null) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }
}