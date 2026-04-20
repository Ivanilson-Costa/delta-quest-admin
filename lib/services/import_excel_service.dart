import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImportExcelService {
  final SupabaseClient client = Supabase.instance.client;

  static const List<String> tiposValidos = [
    'texto',
    'numero',
    'unica',
    'multipla',
    'booleano',
    'escala',
  ];

  Future<void> importarPerguntas(String questionarioId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;

    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo selecionado.');
    }

    final Excel excel = Excel.decodeBytes(bytes);

    if (!excel.tables.keys.contains('perguntas')) {
      throw Exception('A aba "perguntas" não foi encontrada no arquivo.');
    }

    final Sheet sheet = excel.tables['perguntas']!;
    final List<List<Data?>> rows = sheet.rows;

    if (rows.isEmpty) {
      throw Exception('A planilha está vazia.');
    }

    final List<String> headers = rows.first
        .map((e) => e?.value?.toString().trim() ?? '')
        .toList();

    final List<String> colunasObrigatorias = [
      'ordem',
      'codigo',
      'pergunta',
      'tipo',
      'obrigatoria',
      'classificatoria',
    ];

    for (final coluna in colunasObrigatorias) {
      if (!headers.contains(coluna)) {
        throw Exception('Coluna obrigatória ausente: "$coluna".');
      }
    }

    final List<Map<String, dynamic>> batch = [];
    final Set<String> codigos = {};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, dynamic> linha = {};

      for (int j = 0; j < headers.length; j++) {
        final String key = headers[j];
        final dynamic value = j < row.length ? row[j]?.value : null;

        if (key.isNotEmpty) {
          linha[key] = value?.toString().trim() ?? '';
        }
      }

      final int numeroLinha = i + 1;

      if (_linhaVazia(linha)) {
        continue;
      }

      final String codigo = (linha['codigo'] ?? '').toString().trim();
      final String pergunta = (linha['pergunta'] ?? '').toString().trim();
      final String tipo = (linha['tipo'] ?? '').toString().trim().toLowerCase();
      final String ordemTexto = (linha['ordem'] ?? '').toString().trim();

      final String obrigatoriaTexto = _normalizarSimNao(linha['obrigatoria']);
      final String classificatoriaTexto =
          _normalizarSimNao(linha['classificatoria']);

      if (codigo.isEmpty) {
        throw Exception('Linha $numeroLinha: o campo "codigo" está vazio.');
      }

      if (codigos.contains(codigo)) {
        throw Exception('Linha $numeroLinha: código duplicado "$codigo".');
      }
      codigos.add(codigo);

      if (pergunta.isEmpty) {
        throw Exception('Linha $numeroLinha: o campo "pergunta" está vazio.');
      }

      if (!tiposValidos.contains(tipo)) {
        throw Exception(
          'Linha $numeroLinha: tipo inválido "$tipo". '
          'Use um destes: ${tiposValidos.join(', ')}.',
        );
      }

      final int? ordem = int.tryParse(ordemTexto);
      if (ordem == null) {
        throw Exception(
          'Linha $numeroLinha: o campo "ordem" deve ser numérico.',
        );
      }

      if (!_simNaoValido(obrigatoriaTexto)) {
        throw Exception(
          'Linha $numeroLinha: "obrigatoria" deve ser "Sim" ou "Não".',
        );
      }

      if (!_simNaoValido(classificatoriaTexto)) {
        throw Exception(
          'Linha $numeroLinha: "classificatoria" deve ser "Sim" ou "Não".',
        );
      }

      final String opcoesTexto = (linha['opcoes'] ?? '').toString().trim();

      final bool exigeOpcoes =
          tipo == 'unica' || tipo == 'multipla' || tipo == 'escala';

      if (exigeOpcoes && opcoesTexto.isEmpty) {
        throw Exception(
          'Linha $numeroLinha: o tipo "$tipo" exige o preenchimento de "opcoes".',
        );
      }

      final List<String>? opcoes = opcoesTexto.isNotEmpty
          ? opcoesTexto
              .split('|')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : null;

      final String condicaoExibicao =
          (linha['condicao_exibicao'] ?? '').toString().trim();
      final String skipCondicao =
          (linha['skip_condicao'] ?? '').toString().trim();
      final String skipDestino =
          (linha['skip_destino'] ?? '').toString().trim();
      final String bloco = (linha['bloco'] ?? '').toString().trim();

      if (skipDestino.isNotEmpty && skipCondicao.isEmpty) {
        throw Exception(
          'Linha $numeroLinha: se "skip_destino" foi informado, '
          '"skip_condicao" também deve ser informado.',
        );
      }

      batch.add({
        'questionario_id': questionarioId,
        'ordem': ordem,
        'codigo': codigo,
        'texto': pergunta,
        'tipo': tipo,
        'obrigatoria': obrigatoriaTexto == 'sim',
        'classificatoria': classificatoriaTexto == 'sim',
        'opcoes': opcoes,
        'condicao_exibicao':
            condicaoExibicao.isEmpty ? null : condicaoExibicao,
        'skip_condicao': skipCondicao.isEmpty ? null : skipCondicao,
        'skip_destino': skipDestino.isEmpty ? null : skipDestino,
        'bloco': bloco.isEmpty ? null : bloco,
      });
    }

    if (batch.isEmpty) {
      throw Exception('Nenhuma pergunta válida foi encontrada para importação.');
    }

    await client.from('perguntas').insert(batch);
  }

  bool _linhaVazia(Map<String, dynamic> linha) {
    return linha.values.every(
      (value) => value == null || value.toString().trim().isEmpty,
    );
  }

  String _normalizarSimNao(dynamic valor) {
    final texto = (valor ?? '').toString().trim().toLowerCase();

    if (texto == 'sim') return 'sim';
    if (texto == 'não') return 'nao';
    if (texto == 'nao') return 'nao';

    return texto;
  }

  bool _simNaoValido(String valor) {
    return valor == 'sim' || valor == 'nao';
  }
}