import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera um EPEC assinado para validação externa contra o schema oficial.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_epec_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final encoded = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(encoded),
    password: 'test-password',
  );
  final issueDate = DateTime.utc(2026, 1, 1, 12);
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: issueDate,
    cnpj: '04252011000110',
    model: 55,
    series: 1,
    number: 2,
    tpEmis: 4,
    cNf: '12345679',
  );
  final unsigned = NfeEventBuilder().epec(
    accessKey: key.value,
    cOrgao: 11,
    environment: 2,
    authorTaxId: '04252011000110',
    issuerIe: '123456789',
    applicationVersion: 'FFLIB-0.1.0',
    issueDate: issueDate,
    total: 25.5,
    icms: 4.59,
    destinationUf: 'RO',
    destinationTaxId: '52998224725',
    eventDate: issueDate,
  );
  final signed = await XmlSignatureService.fromPfx(
    identity,
  ).signEvent(unsigned);
  File(arguments[outputIndex + 1]).writeAsStringSync(signed);
}
