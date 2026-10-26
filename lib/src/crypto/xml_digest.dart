import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Algoritmo de digest suportado pelo núcleo criptográfico.
enum XmlDigestAlgorithm {
  /// SHA-1, usado pelo perfil XMLDSig fiscal do PL_010b.
  sha1,

  /// SHA-256.
  sha256,
}

/// Digest calculado sobre a representação textual exata recebida.
class XmlDigest {
  /// Calcula o digest SHA-256 de [xml] e retorna Base64.
  static String base64(
    String xml, {
    XmlDigestAlgorithm algorithm = XmlDigestAlgorithm.sha256,
  }) {
    switch (algorithm) {
      case XmlDigestAlgorithm.sha1:
        final digest = crypto.sha1.convert(utf8.encode(xml));
        return base64Encode(digest.bytes);
      case XmlDigestAlgorithm.sha256:
        final digest = crypto.sha256.convert(utf8.encode(xml));
        return base64Encode(digest.bytes);
    }
  }

  /// Calcula o digest SHA-256 de [xml] e retorna hexadecimal minúsculo.
  static String hex(
    String xml, {
    XmlDigestAlgorithm algorithm = XmlDigestAlgorithm.sha256,
  }) {
    switch (algorithm) {
      case XmlDigestAlgorithm.sha1:
        return crypto.sha1.convert(utf8.encode(xml)).toString();
      case XmlDigestAlgorithm.sha256:
        return crypto.sha256.convert(utf8.encode(xml)).toString();
    }
  }
}

/// Contrato para um provedor externo de assinatura digital XML.
///
/// A implementação concreta deve proteger a chave privada e assinar o
/// `signedInfo` conforme o algoritmo configurado. O núcleo não recebe senhas
/// nem persiste material de chave.
abstract interface class XmlSignatureProvider {
  /// Assina os bytes UTF-8 de `signedInfo` e retorna a assinatura em Base64.
  Future<String> sign(List<int> signedInfo);
}
