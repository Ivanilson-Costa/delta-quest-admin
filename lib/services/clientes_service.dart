import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientesService {
  final SupabaseClient client = Supabase.instance.client;

 Future<List<Map<String, dynamic>>> listarClientes() async {
    final response = await client
        .from('clientes')
        .select()
        .order('created_at', ascending: false);

    debugPrint('RESPOSTA CLIENTES: $response');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> criarCliente({
    required String nome,
    String? plano,
    String? email,
    String? telefone,
    String? responsavelNome,
    String? status,
    String? observacoes,
  }) async {
    await client.from('clientes').insert({
      'nome': nome,
      'plano': plano?.trim().isEmpty == true ? null : plano?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'telefone': telefone?.trim().isEmpty == true ? null : telefone?.trim(),
      'responsavel_nome':
          responsavelNome?.trim().isEmpty == true ? null : responsavelNome?.trim(),
      'status': status ?? 'ativo',
      'observacoes':
          observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    });
  }

  Future<void> atualizarCliente({
    required String id,
    required String nome,
    String? plano,
    String? email,
    String? telefone,
    String? responsavelNome,
    String? status,
    String? observacoes,
  }) async {
    await client.from('clientes').update({
      'nome': nome,
      'plano': plano?.trim().isEmpty == true ? null : plano?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'telefone': telefone?.trim().isEmpty == true ? null : telefone?.trim(),
      'responsavel_nome':
          responsavelNome?.trim().isEmpty == true ? null : responsavelNome?.trim(),
      'status': status ?? 'ativo',
      'observacoes':
          observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    }).eq('id', id);
  }

  Future<void> alterarStatus({
    required String id,
    required String status,
  }) async {
    await client.from('clientes').update({
      'status': status,
    }).eq('id', id);
  }
}