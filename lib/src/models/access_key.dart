import '../exceptions/fiscal_exception.dart';

/// Chave de acesso de 44 dígitos de um documento fiscal eletrônico.
class AccessKey {
  /// Cria uma chave completa e valida seu dígito verificador.
  factory AccessKey(String value) {
    if (!RegExp(r'^\d{44}$').hasMatch(value)) {
      throw const FiscalValidationException(
        'A chave de acesso deve conter 44 dígitos.',
        code: 'INVALID_ACCESS_KEY',
      );
    }
    if (!isValid(value)) {
      throw const FiscalValidationException(
        'O dígito verificador da chave de acesso é inválido.',
        code: 'INVALID_ACCESS_KEY_CHECK_DIGIT',
      );
    }
    return AccessKey._(value);
  }

  const AccessKey._(this.value);

  /// Cria uma chave a partir dos 43 dígitos sem o dígito verificador.
  factory AccessKey.fromBase(String base) {
    if (!RegExp(r'^\d{43}$').hasMatch(base)) {
      throw const FiscalValidationException(
        'A base da chave deve conter 43 dígitos.',
        code: 'INVALID_ACCESS_KEY_BASE',
      );
    }
    return AccessKey._('$base${checkDigit(base)}');
  }

  /// Monta uma chave de acesso a partir dos campos fiscais que a compõem.
  factory AccessKey.fromComponents({
    required String cUf,
    required DateTime issueDate,
    required String cnpj,
    required int model,
    required int series,
    required int number,
    required int tpEmis,
    required String cNf,
  }) {
    final uf = _digits(cUf);
    final rawTaxId = _digits(cnpj);
    final taxId = rawTaxId.length == 11 ? rawTaxId.padLeft(14, '0') : rawTaxId;
    final code = _digits(cNf);
    if (uf.length != 2 || taxId.length != 14 || code.length != 8) {
      throw const FiscalValidationException(
        'UF, CNPJ/CPF e código numérico devem ter 2, 14/11 e 8 dígitos.',
        code: 'INVALID_ACCESS_KEY_COMPONENTS',
      );
    }
    if (model != 55 && model != 65 || tpEmis < 1 || tpEmis > 9) {
      throw const FiscalValidationException(
        'Modelo ou tipo de emissão inválido para a chave.',
        code: 'INVALID_ACCESS_KEY_COMPONENTS',
      );
    }
    if (series < 0 || series > 999 || number < 0 || number > 999999999) {
      throw const FiscalValidationException(
        'Série ou número fora do intervalo da chave.',
        code: 'INVALID_ACCESS_KEY_COMPONENTS',
      );
    }
    if (int.parse(code) == number) {
      throw const FiscalValidationException(
        'O código numérico não pode ser igual ao número da NF-e/NFC-e.',
        code: 'INVALID_ACCESS_KEY_NUMERIC_CODE',
      );
    }
    // O XML fiscal e os eventos do pacote normalizam instantes para UTC.
    // Usar a mesma referência aqui evita que uma data com offset atravesse
    // mês/ano e produza uma chave diferente de `dhEmi`.
    final date = issueDate.toUtc();
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    final base =
        '$uf$year$month$taxId${model.toString().padLeft(2, '0')}'
        '${series.toString().padLeft(3, '0')}'
        '${number.toString().padLeft(9, '0')}$tpEmis$code';
    return AccessKey.fromBase(base);
  }

  /// Valor textual da chave.
  final String value;

  /// Calcula o dígito verificador módulo 11.
  static int checkDigit(String base) {
    if (!RegExp(r'^\d{43}$').hasMatch(base)) {
      throw const FiscalValidationException(
        'A base da chave deve conter 43 dígitos.',
        code: 'INVALID_ACCESS_KEY_BASE',
      );
    }
    var weight = 2;
    var sum = 0;
    for (var index = base.length - 1; index >= 0; index--) {
      sum += int.parse(base[index]) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    final remainder = sum % 11;
    return remainder == 0 || remainder == 1 ? 0 : 11 - remainder;
  }

  /// Verifica formato e dígito verificador.
  static bool isValid(String value) {
    if (!RegExp(r'^\d{44}$').hasMatch(value)) return false;
    return int.parse(value[43]) == checkDigit(value.substring(0, 43));
  }

  /// Retorna o modelo codificado na chave completa.
  static int modelOf(String value) => int.parse(value.substring(20, 22));

  /// Retorna o tipo de emissão (`tpEmis`) codificado na chave completa.
  static int emissionTypeOf(String value) => int.parse(value[34]);

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  @override
  String toString() => value;
}
