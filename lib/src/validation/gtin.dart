import '../exceptions/fiscal_exception.dart';

/// Validador de códigos GTIN conforme o dígito verificador Mod-10.
class Gtin {
  Gtin._();

  /// Retorna verdadeiro para GTIN-8, GTIN-12, GTIN-13 ou GTIN-14 válido.
  static bool isValid(String value) {
    final digits = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
    if (![8, 12, 13, 14].contains(digits.length)) return false;
    if (RegExp(r'^(\d)\1{7,13}$').hasMatch(digits)) return false;
    var sum = 0;
    var weightThree = true;
    for (var index = digits.length - 2; index >= 0; index--) {
      sum += int.parse(digits[index]) * (weightThree ? 3 : 1);
      weightThree = !weightThree;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(digits[digits.length - 1]);
  }

  /// Valida ou lança uma exceção fiscal com código estável.
  static void assertValid(String value) {
    if (!isValid(value)) {
      throw const FiscalValidationException(
        'GTIN inválido; esperado GTIN-8, GTIN-12, GTIN-13 ou GTIN-14 com Mod-10 válido.',
        code: 'INVALID_GTIN',
      );
    }
  }
}
