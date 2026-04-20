import 'package:supabase_flutter/supabase_flutter.dart';

class ClientAccessService {
  final SupabaseClient client = Supabase.instance.client;

  Future<void> criarAcessoCliente({
    required String clienteId,
    required String nome,
    required String email,
    required String password,
  }) async {
    final response = await client.functions.invoke(
      'quick-service',
      body: {
        'cliente_id': clienteId,
        'nome': nome,
        'email': email,
        'password': password,
      },
    );

    print('FUNCTION STATUS: ${response.status}');
    print('FUNCTION DATA: ${response.data}');

    if (response.status != 200) {
      if (response.data is Map && response.data['error'] != null) {
        throw Exception(response.data['error'].toString());
      }
      throw Exception('Erro ao criar acesso');
    }
  }
}