import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionariosService {
  final client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listar() async {
    final res = await client
        .from('questionarios')
        .select('*, pesquisas(titulo)')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> criar({
    required String pesquisaId,
    required String titulo,
    String? descricao,
  }) async {
    await client.from('questionarios').insert({
      'pesquisa_id': pesquisaId,
      'titulo': titulo,
      'descricao': descricao,
      'status': 'ativo',
    });
  }

  Future<void> atualizar({
    required String id,
    required String pesquisaId,
    required String titulo,
    String? descricao,
  }) async {
    await client.from('questionarios').update({
      'pesquisa_id': pesquisaId,
      'titulo': titulo,
      'descricao': descricao,
    }).eq('id', id);
  }

  Future<void> deletar(String id) async {
    await client.from('questionarios').update({
      'deleted_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }
}