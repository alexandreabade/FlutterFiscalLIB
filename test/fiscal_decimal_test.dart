import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('soma e multiplica sem erro binário de ponto flutuante', () {
    final result = FiscalDecimal.parse('0.1') + FiscalDecimal.parse('0.2');
    expect(result.toFixed(2), '0.30');
    expect(
      (FiscalDecimal.parse('0.1') * FiscalDecimal.parse('3')).toFixed(2),
      '0.30',
    );
  });

  test('arredonda half-up e preserva valores negativos', () {
    expect(FiscalDecimal.parse('1.005').toFixed(2), '1.01');
    expect(FiscalDecimal.parse('-1.005').toFixed(2), '-1.01');
    expect(FiscalDecimal.parse('10').toFixed(4), '10.0000');
    expect(FiscalDecimal.parse('1e-3').toFixed(4), '0.0010');
  });

  test('total do item e XML usam representação decimal exata', () {
    const item = NfeItem(
      number: 1,
      code: 'A',
      description: 'Produto',
      ncm: '12345678',
      cfop: '5102',
      unit: 'UN',
      quantity: 3,
      unitPrice: 0.1,
    );
    expect(item.totalFormatted, '0.30');
    expect(Tools.formatDecimal(0.1 + 0.2), '0.30');
  });
}
