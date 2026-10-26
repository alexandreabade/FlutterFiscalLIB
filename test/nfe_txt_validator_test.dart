import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  final validator = NfeTxtValidator(layout: NfeTxtLayout.local400());

  test('valida marcadores e quantidade de campos do TXT local 4.00', () {
    final result = validator.validate(
      'NOTAFISCAL|1|\n'
      'A|4.00|NFe123|1|\n'
      'C|Emitente|||||||\n',
    );

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('aceita B19 do leiaute oficial e o alias histórico BA19', () {
    final result = validator.validate(
      'B19|11012604252011000110550010000000011123456784|\n'
      'BA19|11012604252011000110550010000000011123456784|',
    );

    expect(result.isValid, isTrue);
  });

  test('aceita B e YA dos leiautes antigo e estendido', () {
    final result = validator.validate(
      'B|11|12345678|VENDA|55|1|8|2026-01-01T12:00:00-04:00||1|1|1100015|1|1||2|1|0|0|1|||\n'
      'YA|0|01|10||||0|',
    );

    expect(result.isValid, isTrue);
  });

  test('acumula erros de marcador, cardinalidade e terminador', () {
    final result = validator.validate(
      'A|4.00|NFe123|1\n'
      'DESCONHECIDO|x|\n'
      'C|Emitente|\n',
    );

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(3));
    expect(result.errors.join('\n'), contains('terminar com'));
    expect(result.errors.join('\n'), contains('não está definida'));
    expect(result.errors.join('\n'), contains('número de parâmetros'));
  });

  test('rejeita caracteres especiais e campos apenas com espaços', () {
    final result = validator.validate(
      'A|4.00|NFe123|1|\n'
      'C|Emitente <teste>|||||| |\n',
    );

    expect(result.isValid, isFalse);
    expect(result.errors.join('\n'), contains('caracteres especiais'));
    expect(result.errors.join('\n'), contains('apenas espaços'));
  });

  test('assertValid lança erro fiscal para TXT inválido', () {
    expect(
      () => validator.assertValid('A|4.00|NFe123|'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_NFE_TXT',
        ),
      ),
    );
  });
}
