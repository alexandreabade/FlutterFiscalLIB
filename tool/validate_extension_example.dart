import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera eventos de prorrogação para validação externa contra o leiaute de
/// eventos da NF-e.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_extension_example.dart --out arquivo.xml',
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
  ).value;
  final builder = NfeEventBuilder();
  final extension = builder.prorrogacaoRetorno(
    accessKey: key,
    cOrgao: 11,
    environment: 2,
    issuerCnpj: '04252011000110',
    protocol: '123456789012345',
    items: const [ReturnExtensionItem(number: 1, quantity: 2)],
    eventDate: issueDate,
  );
  final cancellation = builder.cancelamentoProrrogacao(
    accessKey: key,
    cOrgao: 11,
    environment: 2,
    issuerCnpj: '04252011000110',
    protocol: '123456789012345',
    eventDate: issueDate,
  );
  final encoded = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(encoded),
    password: 'test-password',
  );
  final signer = XmlSignatureService.fromPfx(identity);
  final signed = await signer.signEvent(
    arguments.contains('--cancel') ? cancellation : extension,
  );
  await File(arguments[outputIndex + 1]).writeAsString(signed);
}
