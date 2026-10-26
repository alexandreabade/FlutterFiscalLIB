import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma inutilização assinada para validação externa contra o schema.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_inutilization_example.dart --out arquivo.xml',
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
  final unsigned = NfeInutilizationBuilder().build(
    cUf: '11',
    environment: 2,
    issuerCnpj: '04252011000110',
    model: 55,
    series: 1,
    startNumber: 10,
    endNumber: 12,
    reason: 'Numeração não utilizada por falha operacional',
    year: DateTime.utc(2026),
  );
  final signed = await XmlSignatureService.fromPfx(
    identity,
  ).signInutilization(unsigned);
  File(arguments[outputIndex + 1]).writeAsStringSync(signed);
}
