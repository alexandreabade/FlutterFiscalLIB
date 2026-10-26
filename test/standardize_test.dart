import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('identifica e converte fixture fiscal para mapa e JSON', () {
    final xml = File('test/fixtures/nfe_minimal.xml').readAsStringSync();
    final standardize = Standardize(xml);

    expect(standardize.whichIs(), 'NFe');
    expect(standardize.key, 'NFe');
    expect(standardize.simpleXml().localName, 'NFe');
    final map = standardize.toArray();
    expect(map['NFe']['infNFe']['attributes']['versao'], '4.00');
    expect(jsonDecode(standardize.toJson())['NFe'], isNotNull);
    expect(standardize.toString(), startsWith('<NFe'));
  });

  test('rejeita XML fiscal vazio ou de outra raiz', () {
    expect(
      () => Standardize().whichIs(),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => Standardize('<root/>').whichIs(),
      throwsA(isA<FiscalValidationException>()),
    );
  });
}
