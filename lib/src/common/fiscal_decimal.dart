import '../exceptions/fiscal_exception.dart';

/// Número decimal exato para cálculos e formatação fiscal.
///
/// O valor é armazenado como inteiro escalado (`unscaled / 10^scale`), sem
/// operações binárias de ponto flutuante. Os modelos legados continuam
/// expondo `double`, mas os totalizadores e o XML usam esta representação.
class FiscalDecimal implements Comparable<FiscalDecimal> {
  /// Cria um decimal a partir de texto decimal, por exemplo `"10.235"`.
  factory FiscalDecimal.parse(String value) {
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw FiscalValidationException(
        'Valor decimal inválido: $value.',
        code: 'INVALID_DECIMAL',
      );
    }
    final sign = match.group(1) == '-' ? -1 : 1;
    final fraction = match.group(3) ?? '';
    final digits = '${match.group(2)}$fraction';
    var unscaled = BigInt.parse(digits) * BigInt.from(sign);
    var scale = fraction.length - int.parse(match.group(4) ?? '0');
    if (scale < 0) {
      unscaled *= BigInt.from(10).pow(-scale);
      scale = 0;
    }
    return FiscalDecimal._(unscaled, scale);
  }

  /// Converte um número finito usando sua representação decimal textual.
  factory FiscalDecimal.fromNum(num value) {
    if (!value.isFinite) {
      throw const FiscalValidationException(
        'O valor decimal deve ser finito.',
        code: 'INVALID_DECIMAL',
      );
    }
    return FiscalDecimal.parse(value.toString());
  }

  const FiscalDecimal._(this.unscaled, this.scale);

  /// Inteiro escalado interno.
  final BigInt unscaled;

  /// Quantidade de casas decimais internas.
  final int scale;

  /// Soma dois valores com alinhamento de escala.
  FiscalDecimal operator +(FiscalDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    return FiscalDecimal._(
      _scaled(targetScale) + other._scaled(targetScale),
      targetScale,
    );
  }

  /// Subtrai dois valores com alinhamento de escala.
  FiscalDecimal operator -(FiscalDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    return FiscalDecimal._(
      _scaled(targetScale) - other._scaled(targetScale),
      targetScale,
    );
  }

  /// Multiplica sem converter para ponto flutuante.
  FiscalDecimal operator *(FiscalDecimal other) =>
      FiscalDecimal._(unscaled * other.unscaled, scale + other.scale);

  /// Calcula o valor correspondente a uma alíquota percentual.
  FiscalDecimal percentage(FiscalDecimal rate) =>
      FiscalDecimal._(unscaled * rate.unscaled, scale + rate.scale + 2);

  /// Formata com [targetScale] casas e arredondamento half-up.
  String toFixed(int targetScale) {
    if (targetScale < 0) {
      throw const FiscalValidationException(
        'A escala decimal não pode ser negativa.',
        code: 'INVALID_DECIMAL_SCALE',
      );
    }
    var value = unscaled;
    if (scale < targetScale) {
      value *= _tenPow(targetScale - scale);
    } else if (scale > targetScale) {
      final divisor = _tenPow(scale - targetScale);
      final quotient = value ~/ divisor;
      final remainder = value.remainder(divisor).abs();
      value = quotient;
      if (remainder * BigInt.from(2) >= divisor) {
        value += unscaled.isNegative ? -BigInt.one : BigInt.one;
      }
    }
    final negative = value.isNegative;
    final digits = value.abs().toString().padLeft(targetScale + 1, '0');
    if (targetScale == 0) return '${negative ? '-' : ''}$digits';
    final split = digits.length - targetScale;
    return '${negative ? '-' : ''}${digits.substring(0, split)}.'
        '${digits.substring(split)}';
  }

  /// Converte para `double` apenas na borda de compatibilidade.
  double toDouble() => double.parse(toFixed(scale));

  /// Indica valor negativo.
  bool get isNegative => unscaled.isNegative;

  BigInt _scaled(int targetScale) => unscaled * _tenPow(targetScale - scale);

  static BigInt _tenPow(int exponent) => BigInt.from(10).pow(exponent);

  @override
  int compareTo(FiscalDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    return _scaled(targetScale).compareTo(other._scaled(targetScale));
  }

  @override
  String toString() => toFixed(scale);
}
