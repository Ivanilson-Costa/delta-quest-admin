import 'package:supabase_flutter/supabase_flutter.dart';

class PerguntasService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listar(String questionarioId) async {
    final res = await client
        .from('perguntas')
        .select()
        .eq('questionario_id', questionarioId)
        .isFilter('deleted_at', null)
        .order('ordem', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> criar({
    required String questionarioId,
    required String texto,
    required String tipo,
    required String codigo,
    int ordem = 1,
    bool obrigatoria = false,
    bool classificatoria = false,
    List<String>? opcoes,
  }) async {
    await client.from('perguntas').insert({
      'questionario_id': questionarioId,
      'codigo': codigo,
      'texto': texto,
      'tipo': tipo,
      'ordem': ordem,
      'obrigatoria': obrigatoria,
      'classificatoria': classificatoria,
      'opcoes': opcoes,
    });
  }

  Future<void> deletar(String id) async {
    await client.from('perguntas').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}