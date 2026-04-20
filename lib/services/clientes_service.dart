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

    final List<Map<String, dynamic>> clientes =
        List<Map<String, dynamic>>.from(clientesResponse);

    final List<Map<String, dynamic>> pesquisas =
        List<Map<String, dynamic>>.from(pesquisasResponse);

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

      final totalPesquisas = pesquisasDoCliente.length;
      final pesquisasAtivas = pesquisasDoCliente.where((p) {
        final status = (p['status'] ?? '').toString();
        return status == 'em_andamento' || status == 'planejada';
      }).length;

      final pesquisasConcluidas = pesquisasDoCliente.where((p) {
        final status = (p['status'] ?? '').toString();
        return status == 'concluida';
      }).length;

      final pesquisasPausadas = pesquisasDoCliente.where((p) {
        final status = (p['status'] ?? '').toString();
        return status == 'pausada';
      }).length;

      final pesquisasCanceladas = pesquisasDoCliente.where((p) {
        final status = (p['status'] ?? '').toString();
        return status == 'cancelada';
      }).length;

      return {
        ...cliente,
        'total_pesquisas': totalPesquisas,
        'pesquisas_ativas': pesquisasAtivas,
        'pesquisas_concluidas': pesquisasConcluidas,
        'pesquisas_pausadas': pesquisasPausadas,
        'pesquisas_canceladas': pesquisasCanceladas,
      };
    }).toList();
  }

  Future<void> criarCliente({
    required String nome,
    String? plano,
    String? email,
    String? telefone,
    String? responsavelNome,
    String status = 'ativo',
    String? observacoes,
  }) async {
    await client.from('clientes').insert({
      'nome': nome.trim(),
      'plano': _nullSeVazio(plano),
      'email': _nullSeVazio(email),
      'telefone': _nullSeVazio(telefone),
      'responsavel_nome': _nullSeVazio(responsavelNome),
      'status': status,
      'observacoes': _nullSeVazio(observacoes),
    });
  }

  Future<void> atualizarCliente({
    required String id,
    required String nome,
    String? plano,
    String? email,
    String? telefone,
    String? responsavelNome,
    required String status,
    String? observacoes,
  }) async {
    await client.from('clientes').update({
      'nome': nome.trim(),
      'plano': _nullSeVazio(plano),
      'email': _nullSeVazio(email),
      'telefone': _nullSeVazio(telefone),
      'responsavel_nome': _nullSeVazio(responsavelNome),
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