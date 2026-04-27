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

  Future<List<Map<String, dynamic>>> listarBlocos(String questionarioId) async {
    final res = await client
        .from('blocos_questionario')
        .select()
        .eq('questionario_id', questionarioId)
        .isFilter('deleted_at', null)
        .order('ordem', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> listarRegrasPulo(
    String questionarioId,
  ) async {
    final perguntas = await listar(questionarioId);
    final ids = perguntas.map((p) => p['id'].toString()).toList();

    if (ids.isEmpty) return [];

    final res = await client
        .from('regras_pulo_pergunta')
        .select()
        .inFilter('pergunta_origem_id', ids)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> criar({
    required String questionarioId,
    required String texto,
    required String tipo,
    required String codigo,
    String? blocoId,
    String? subtitulo,
    int ordem = 1,
    bool obrigatoria = true,
    bool classificatoria = false,
    bool permiteNaoSeAplica = false,
    String? perguntaDestinoNaoSeAplica,
    List<Map<String, dynamic>>? opcoes,
    int? escalaMin,
    int? escalaMax,
    List<Map<String, dynamic>>? emojiMap,
    String? ajuda,
  }) async {
    await client.from('perguntas').insert({
      'questionario_id': questionarioId,
      'bloco_id': _nullSeVazio(blocoId),
      'codigo': _nullSeVazio(codigo),
      'texto': texto.trim(),
      'subtitulo': _nullSeVazio(subtitulo),
      'tipo': tipo,
      'ordem': ordem,
      'obrigatoria': obrigatoria,
      'classificatoria': classificatoria,
      'permite_nao_se_aplica': permiteNaoSeAplica,
      'pergunta_destino_nao_se_aplica':
          _nullSeVazio(perguntaDestinoNaoSeAplica),
      'opcoes': opcoes,
      'escala_min': escalaMin,
      'escala_max': escalaMax,
      'emoji_map': emojiMap,
      'ajuda': _nullSeVazio(ajuda),
    });
  }

  Future<void> atualizar({
    required String id,
    required String questionarioId,
    required String texto,
    required String tipo,
    required String codigo,
    String? blocoId,
    String? subtitulo,
    int ordem = 1,
    bool obrigatoria = true,
    bool classificatoria = false,
    bool permiteNaoSeAplica = false,
    String? perguntaDestinoNaoSeAplica,
    List<Map<String, dynamic>>? opcoes,
    int? escalaMin,
    int? escalaMax,
    List<Map<String, dynamic>>? emojiMap,
    String? ajuda,
  }) async {
    await client.from('perguntas').update({
      'questionario_id': questionarioId,
      'bloco_id': _nullSeVazio(blocoId),
      'codigo': _nullSeVazio(codigo),
      'texto': texto.trim(),
      'subtitulo': _nullSeVazio(subtitulo),
      'tipo': tipo,
      'ordem': ordem,
      'obrigatoria': obrigatoria,
      'classificatoria': classificatoria,
      'permite_nao_se_aplica': permiteNaoSeAplica,
      'pergunta_destino_nao_se_aplica':
          _nullSeVazio(perguntaDestinoNaoSeAplica),
      'opcoes': opcoes,
      'escala_min': escalaMin,
      'escala_max': escalaMax,
      'emoji_map': emojiMap,
      'ajuda': _nullSeVazio(ajuda),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deletar(String id) async {
    await client.from('perguntas').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> criarBloco({
    required String questionarioId,
    required String titulo,
    String? descricao,
    int ordem = 1,
  }) async {
    await client.from('blocos_questionario').insert({
      'questionario_id': questionarioId,
      'titulo': titulo.trim(),
      'descricao': _nullSeVazio(descricao),
      'ordem': ordem,
    });
  }

  Future<void> atualizarBloco({
    required String id,
    required String titulo,
    String? descricao,
    int ordem = 1,
  }) async {
    await client.from('blocos_questionario').update({
      'titulo': titulo.trim(),
      'descricao': _nullSeVazio(descricao),
      'ordem': ordem,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deletarBloco(String id) async {
    await client.from('blocos_questionario').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    await client.from('perguntas').update({
      'bloco_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('bloco_id', id);
  }

  Future<void> criarRegraPulo({
    required String perguntaOrigemId,
    required String valorResposta,
    String? perguntaDestinoId,
    bool encerrarQuestionario = false,
  }) async {
    await client.from('regras_pulo_pergunta').insert({
      'pergunta_origem_id': perguntaOrigemId,
      'valor_resposta': valorResposta.trim(),
      'pergunta_destino_id': encerrarQuestionario
          ? null
          : _nullSeVazio(perguntaDestinoId),
      'encerrar_questionario': encerrarQuestionario,
    });
  }

  Future<void> deletarRegraPulo(String id) async {
    await client.from('regras_pulo_pergunta').delete().eq('id', id);
  }

  String? _nullSeVazio(String? valor) {
    if (valor == null) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }
}