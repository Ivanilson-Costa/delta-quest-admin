import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionariosService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listar() async {
    final response = await client
        .from('questionarios')
        .select('''
          id,
          titulo,
          subtitulo,
          descricao,
          status,
          pesquisa_id,
          created_at,
          updated_at,
          deleted_at,
          pesquisas (
            id,
            titulo,
            status,
            data_inicio,
            data_fim
          )
        ''')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> questionarios =
        List<Map<String, dynamic>>.from(response);

    final perguntasResponse = await client
        .from('perguntas')
        .select('id, questionario_id')
        .isFilter('deleted_at', null);

    final List<Map<String, dynamic>> perguntas =
        List<Map<String, dynamic>>.from(perguntasResponse);

    final Map<String, int> perguntasCount = {};

    for (final pergunta in perguntas) {
      final questionarioId = (pergunta['questionario_id'] ?? '').toString();
      if (questionarioId.isEmpty) continue;

      perguntasCount[questionarioId] =
          (perguntasCount[questionarioId] ?? 0) + 1;
    }

    return questionarios.map((q) {
      final id = (q['id'] ?? '').toString();

      return {
        ...q,
        'perguntas_count': perguntasCount[id] ?? 0,
      };
    }).toList();
  }

  Future<void> criar({
    required String pesquisaId,
    required String titulo,
    String? subtitulo,
    String? descricao,
    String status = 'rascunho',
  }) async {
    await client.from('questionarios').insert({
      'pesquisa_id': pesquisaId,
      'titulo': titulo.trim(),
      'subtitulo': _nullSeVazio(subtitulo),
      'descricao': _nullSeVazio(descricao),
      'status': status,
    });
  }

  Future<void> atualizar({
    required String id,
    required String pesquisaId,
    required String titulo,
    String? subtitulo,
    String? descricao,
    String status = 'rascunho',
  }) async {
    await client.from('questionarios').update({
      'pesquisa_id': pesquisaId,
      'titulo': titulo.trim(),
      'subtitulo': _nullSeVazio(subtitulo),
      'descricao': _nullSeVazio(descricao),
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deletar(String id) async {
    await client.from('questionarios').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  String? _nullSeVazio(String? valor) {
    if (valor == null) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }
}