import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera o evento 110150 assinado para validação externa contra o XSD oficial.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_interested_actor_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final issueDate = DateTime.utc(2026, 1, 1, 12);
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: issueDate,
    cnpj: '04252011000110',
    model: 55,
    series: 1,
    number: 3,
    tpEmis: 1,
    cNf: '12345680',
  );
  final unsigned = NfeEventBuilder().atorInteressado(
    accessKey: key.value,
    cOrgao: 11,
    environment: 2,
    authorTaxId: '04252011000110',
    authorStateCode: 11,
    authorType: '3',
    applicationVersion: 'FFLIB-0.1.0',
    authorizedTaxId: '04252011000110',
    authorizationType: '1',
    occurredAt: issueDate,
  );
  final encoded = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(encoded),
    password: 'test-password',
  );
  final signed = await XmlSignatureService.fromPfx(
    identity,
  ).signEvent(unsigned);
  File(arguments[outputIndex + 1]).writeAsStringSync(signed);
}
