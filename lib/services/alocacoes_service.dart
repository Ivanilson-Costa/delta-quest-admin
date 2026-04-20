import 'package:supabase_flutter/supabase_flutter.dart';

class AlocacoesService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listarAlocacoes() async {
    final response = await client.from('alocacoes').select('''
          id,
          created_at,
          pesquisas (
            id,
            titulo,
            status
          ),
          colaboradores (
            id,
            ativo,
            profiles (
              id,
              nome,
              email
            )
          )
        ''').order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> criarAlocacao({
    required String pesquisaId,
    required String colaboradorId,
  }) async {
    await client.from('alocacoes').insert({
      'pesquisa_id': pesquisaId,
      'colaborador_id': colaboradorId,
    });
  }

  Future<void> excluirAlocacao(String id) async {
    await client.from('alocacoes').delete().eq('id', id);
  }
}