import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';

import 'xml_digest.dart';

/// Verificador abstrato usado pela validação de XMLDSig.
abstract interface class XmlSignatureVerifier {
  /// Verifica uma assinatura Base64 sobre os bytes informados.
  bool verify(List<int> signedInfo, String signatureBase64);
}

/// Provedor RSA PKCS#1 v1.5 com digest SHA-256.
class RsaSha256SignatureProvider implements XmlSignatureProvider {
  /// Cria o provedor com uma chave privada já carregada pelo aplicativo.
  RsaSha256SignatureProvider(this.privateKey);

  /// Chave privada RSA. Nunca é serializada ou registrada pela biblioteca.
  final RSAPrivateKey privateKey;

  @override
  Future<String> sign(List<int> signedInfo) async {
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(Uint8List.fromList(signedInfo));
    return base64Encode((signature as RSASignature).bytes);
  }
}

/// Verificador RSA correspondente ao provedor SHA-256.
class RsaSha256SignatureVerifier implements XmlSignatureVerifier {
  /// Cria o verificador com uma chave pública.
  RsaSha256SignatureVerifier(this.publicKey);

  /// Chave pública RSA.
  final RSAPublicKey publicKey;

  /// Verifica uma assinatura Base64 sobre [signedInfo].
  @override
  bool verify(List<int> signedInfo, String signatureBase64) {
    try {
      final verifier = Signer('SHA-256/RSA')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      return verifier.verifySignature(
        Uint8List.fromList(signedInfo),
        RSASignature(base64Decode(signatureBase64)),
      );
    } on Object {
      return false;
    }
  }
}

/// Provedor RSA PKCS#1 v1.5 com digest SHA-1, conforme o perfil XMLDSig
/// fiscal dos schemas NF-e/NFC-e distribuídos no PL_010b.
class RsaSha1SignatureProvider implements XmlSignatureProvider {
  /// Cria o provedor com uma chave privada já carregada.
  RsaSha1SignatureProvider(this.privateKey);

  /// Chave privada RSA.
  final RSAPrivateKey privateKey;

  @override
  Future<String> sign(List<int> signedInfo) async {
    final signer = Signer('SHA-1/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(Uint8List.fromList(signedInfo));
    return base64Encode((signature as RSASignature).bytes);
  }
}

/// Verificador RSA correspondente ao provedor SHA-1 fiscal.
class RsaSha1SignatureVerifier implements XmlSignatureVerifier {
  /// Cria o verificador com uma chave pública.
  RsaSha1SignatureVerifier(this.publicKey);

  /// Chave pública RSA.
  final RSAPublicKey publicKey;

  /// Verifica uma assinatura Base64 sobre [signedInfo].
  @override
  bool verify(List<int> signedInfo, String signatureBase64) {
    try {
      final verifier = Signer('SHA-1/RSA')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      return verifier.verifySignature(
        Uint8List.fromList(signedInfo),
        RSASignature(base64Decode(signatureBase64)),
      );
    } on Object {
      return false;
    }
  }
}
