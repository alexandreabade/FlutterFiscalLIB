import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:xml/xml.dart';

/// Verifica uma assinatura XMLDSig gerada pelo núcleo com OpenSSL.
///
/// Essa ferramenta valida a interoperabilidade da assinatura RSA-SHA1 com um
/// verificador externo, sem depender do verificador PointyCastle interno.
Future<void> main() async {
  final fixture = File('test/fixtures/synthetic_a1.p12.b64');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(
      fixture.readAsStringSync().replaceAll(RegExp(r'\s'), ''),
    ),
    password: 'test-password',
  );
  final signed = await XmlSignatureService.fromPfx(
    identity,
  ).sign('<NFe><infNFe Id="NFe123" versao="4.00"><ide/></infNFe></NFe>');
  final document = XmlDocument.parse(signed);
  final signature = document.rootElement.getElement('Signature');
  final signedInfo = signature?.getElement('SignedInfo');
  final value = signature?.getElement('SignatureValue')?.innerText;
  if (signedInfo == null || value == null || value.isEmpty) {
    throw StateError('Assinatura XMLDSig incompleta.');
  }

  final directory = await Directory.systemTemp.createTemp(
    'flutter-fiscal-openssl-',
  );
  try {
    final signedInfoPath = '${directory.path}/signed-info.xml';
    final signaturePath = '${directory.path}/signature.bin';
    final certificatePath = '${directory.path}/certificate.pem';
    final publicKeyPath = '${directory.path}/public-key.pem';
    await File(
      signedInfoPath,
    ).writeAsString(XmlCanonicalizer.canonicalize(signedInfo));
    await File(signaturePath).writeAsBytes(base64Decode(value));
    await File(certificatePath).writeAsString(identity.certificate.pem);

    final publicKey = await Process.run('openssl', [
      'x509',
      '-in',
      certificatePath,
      '-pubkey',
      '-noout',
    ]);
    if (publicKey.exitCode != 0) {
      throw StateError(
        'OpenSSL não extraiu a chave pública: ${publicKey.stderr}',
      );
    }
    await File(publicKeyPath).writeAsString(publicKey.stdout as String);

    final verification = await Process.run('openssl', [
      'dgst',
      '-sha1',
      '-verify',
      publicKeyPath,
      '-signature',
      signaturePath,
      signedInfoPath,
    ]);
    if (verification.exitCode != 0 ||
        !verification.stdout.toString().contains('Verified OK')) {
      throw StateError(
        'OpenSSL rejeitou a SignatureValue: ${verification.stdout} ${verification.stderr}',
      );
    }
    stdout.writeln('XMLDSig RSA-SHA1 verificada externamente com OpenSSL.');
  } finally {
    await directory.delete(recursive: true);
  }
}
