import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera um evento de comprovante de entrega para validação XSD externa.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_delivery_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2026, 1, 1),
    cnpj: '04252011000110',
    model: 55,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345678',
  ).value;
  final xml = NfeEventBuilder().comprovanteEntrega(
    accessKey: key,
    cOrgao: 11,
    environment: 2,
    issuerCnpj: '04252011000110',
    applicationVersion: '1.0.0',
    deliveryDate: DateTime.utc(2026, 1, 2, 10),
    documentNumber: 'RG123456',
    recipientName: 'Pessoa Recebedora',
    hashComprovante: 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    latitude: '-8.761234',
    longitude: '-63.903456',
    hashDate: DateTime.utc(2026, 1, 2, 10, 1),
    eventDate: DateTime.utc(2026, 1, 2, 10, 2),
  );
  final pfxBase64 = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(pfxBase64),
    password: 'test-password',
  );
  final signed = await XmlSignatureService.fromPfx(identity).signEvent(xml);
  await File(arguments[outputIndex + 1]).writeAsString(signed);
}
