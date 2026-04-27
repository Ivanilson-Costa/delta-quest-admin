import 'package:supabase_flutter/supabase_flutter.dart';

class AlocacoesService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listarAlocacoes() async {
    final response = await client.from('alocacoes').select('''
      id,
      colaborador_id,
      pesquisa_id,
      created_at,
      pesquisas (
        id,
        titulo,
        status
      ),
      profiles!alocacoes_colaborador_id_fkey (
        id,
        nome,
        email,
        ativo
      )
    ''').order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> listarColaboradores() async {
    final response = await client
        .from('profiles')
        .select('id, nome, email, ativo')
        .eq('tipo', 'colaborador')
        .eq('ativo', true)
        .isFilter('deleted_at', null)
        .order('nome');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> listarPesquisas() async {
    final response = await client
        .from('pesquisas')
        .select('id, titulo, status')
        .isFilter('deleted_at', null)
        .order('titulo');

    return List<Map<String, dynamic>>.from(response);
  }

 Future<void> criarAlocacao({
  required String pesquisaId,
  required String colaboradorId,
}) async {
  await client.from('alocacoes').upsert({
    'pesquisa_id': pesquisaId,
    'colaborador_id': colaboradorId,
  }, onConflict: 'colaborador_id,pesquisa_id');
}

Future<void> criarAlocacoesEmLote({
  required String pesquisaId,
  required List<String> colaboradoresIds,
}) async {
  if (colaboradoresIds.isEmpty) return;

  final registros = colaboradoresIds.map((colaboradorId) {
    return {
      'pesquisa_id': pesquisaId,
      'colaborador_id': colaboradorId,
    };
  }).toList();

  await client.from('alocacoes').upsert(
    registros,
    onConflict: 'colaborador_id,pesquisa_id',
  );
}
  Future<void> excluirAlocacao(String id) async {
    await client.from('alocacoes').delete().eq('id', id);
  }
}