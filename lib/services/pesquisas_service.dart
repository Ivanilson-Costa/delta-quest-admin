import 'package:supabase_flutter/supabase_flutter.dart';

class PesquisasService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listarPesquisas() async {
    final response = await client
        .from('pesquisas')
        .select('*, clientes(nome)')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> criarPesquisa({
    required String clienteId,
    required String titulo,
    String? descricao,
    String? status,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? metaRespostas,
    int? totalEsperado,
    String? observacoes,
  }) async {
    final user = client.auth.currentUser;

    await client.from('pesquisas').insert({
      'cliente_id': clienteId,
      'titulo': titulo,
      'descricao': descricao?.trim().isEmpty == true ? null : descricao?.trim(),
      'status': status ?? 'planejada',
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'meta_respostas': metaRespostas,
      'total_esperado': totalEsperado,
      'observacoes':
          observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
      'created_by': user?.id,
    });
  }

  Future<void> atualizarPesquisa({
    required String id,
    required String clienteId,
    required String titulo,
    String? descricao,
    String? status,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? metaRespostas,
    int? totalEsperado,
    String? observacoes,
  }) async {
    await client.from('pesquisas').update({
      'cliente_id': clienteId,
      'titulo': titulo,
      'descricao': descricao?.trim().isEmpty == true ? null : descricao?.trim(),
      'status': status ?? 'planejada',
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'meta_respostas': metaRespostas,
      'total_esperado': totalEsperado,
      'observacoes':
          observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    }).eq('id', id);
  }

  Future<void> softDeletePesquisa(String id) async {
    await client.from('pesquisas').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}