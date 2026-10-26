import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('roteia contingência SVC conforme a UF', () {
    expect(Contingency.svcModeForState('RO'), ContingencyMode.svcAn);
    expect(Contingency.svcModeForState('ap'), ContingencyMode.svcRs);

    final contingency = Contingency.forState(
      state: 'RO',
      activatedAt: DateTime.utc(2026, 1, 1),
      reason: 'Indisponibilidade do autorizador estadual',
    );
    expect(contingency.mode, ContingencyMode.svcAn);
    expect(contingency.mode.code, 6);
  });

  test('rejeita UF sem roteamento SVC', () {
    expect(
      () => Contingency.svcModeForState('XX'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_CONTINGENCY_STATE',
        ),
      ),
    );
  });
}
