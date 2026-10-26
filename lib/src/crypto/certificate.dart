import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/rc2_engine.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/key_derivators/pkcs12_parameter_generator.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/pointycastle.dart';

import '../exceptions/fiscal_exception.dart';
import 'rsa_signature.dart';

/// Certificado X.509 em DER, sem armazenar senha ou chave privada.
class Certificate {
  /// Cria um certificado a partir dos bytes DER.
  Certificate(Uint8List der) : _der = Uint8List.fromList(der) {
    if (der.isEmpty) {
      throw const FiscalValidationException(
        'O certificado não pode ser vazio.',
        code: 'EMPTY_CERTIFICATE',
      );
    }
  }

  /// Decodifica um PEM contendo `CERTIFICATE`.
  factory Certificate.fromPem(String pem) {
    final match = RegExp(
      r'-----BEGIN CERTIFICATE-----([\s\S]+?)-----END CERTIFICATE-----',
    ).firstMatch(pem);
    if (match == null) {
      throw const FiscalValidationException(
        'PEM de certificado X.509 não encontrado.',
        code: 'INVALID_CERTIFICATE_PEM',
      );
    }
    try {
      return Certificate(
        Uint8List.fromList(
          base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), '')),
        ),
      );
    } on FormatException catch (error) {
      throw FiscalValidationException(
        'Base64 do certificado inválido.',
        code: 'INVALID_CERTIFICATE_PEM',
        cause: error,
      );
    }
  }

  /// Lê o certificado X.509 de um contêiner PKCS#12/PFX.
  ///
  /// A senha é usada apenas durante a leitura: não é armazenada no objeto.
  /// O MAC do contêiner é verificado antes de qualquer certificado ser
  /// retornado. A extração da chave privada permanece deliberadamente fora
  /// desta classe; ela deve ser fornecida a um provedor de assinatura seguro.
  factory Certificate.fromPfx({
    required Uint8List bytes,
    required String password,
  }) {
    try {
      final reader = _PfxReader(bytes, password);
      return Certificate(reader.certificateDer());
    } on FiscalException {
      rethrow;
    } on Object catch (error) {
      throw FiscalValidationException(
        'Contêiner PKCS#12 inválido ou não suportado.',
        code: 'INVALID_PKCS12',
        cause: error,
      );
    }
  }

  /// Alias compatível com `Certificate::readPfx()` do NFePHP.
  ///
  /// A identidade retornada mantém certificado, cadeia e chave privada em
  /// memória, sem armazenar a senha do contêiner.
  static PfxIdentity readPfx(Uint8List content, String password) =>
      PfxIdentity.fromPfx(bytes: content, password: password);

  /// Exporta um certificado e uma chave RSA PKCS#8 para um contêiner PFX.
  ///
  /// A chave privada é protegida pelo algoritmo PKCS#12
  /// `pbeWithSHAAnd3-KeyTripleDES-CBC` e o contêiner recebe MAC SHA-1. A
  /// senha não é mantida após a operação. [privateKeyInfoDer] deve conter um
  /// `PrivateKeyInfo` PKCS#8, como o exposto por [PfxIdentity].
  static Uint8List writePfx({
    required Certificate certificate,
    required Uint8List privateKeyInfoDer,
    required String password,
    List<Certificate> certificateChain = const [],
    int iterations = 2048,
  }) => _PfxWriter(
    certificate: certificate,
    privateKeyInfoDer: privateKeyInfoDer,
    password: password,
    certificateChain: certificateChain,
    iterations: iterations,
  ).write();

  /// Lê um certificado PFX/P12 de arquivo sem persistir a senha.
  static Future<Certificate> fromPfxFile({
    required String path,
    required String password,
  }) async => Certificate.fromPfx(
    bytes: await File(path).readAsBytes(),
    password: password,
  );

  /// Conteúdo DER do certificado.
  final Uint8List _der;

  /// Conteúdo DER do certificado.
  ///
  /// Uma cópia defensiva é retornada para impedir que consumidores alterem o
  /// material interno usado em validações e autenticação TLS.
  Uint8List get der => Uint8List.fromList(_der);

  /// Certificado DER codificado em Base64, para uso em `X509Certificate`.
  String get base64 => base64Encode(der);

  /// Chave pública RSA contida no `SubjectPublicKeyInfo` do certificado.
  RSAPublicKey get rsaPublicKey {
    try {
      final root = ASN1Parser(der).nextObject();
      final tbs = (root as ASN1Sequence).elements!.first as ASN1Sequence;
      final elements = tbs.elements!;
      final offset = elements.first.tag == 0xa0 ? 1 : 0;
      final info = elements[offset + 5] as ASN1Sequence;
      final bits = info.elements!.elementAt(1) as ASN1BitString;
      final rsa =
          ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
              as ASN1Sequence;
      final modulus = (rsa.elements!.elementAt(0) as ASN1Integer).integer!;
      final exponent = (rsa.elements!.elementAt(1) as ASN1Integer).integer!;
      return RSAPublicKey(modulus, exponent);
    } on FiscalException {
      rethrow;
    } on Object catch (error) {
      throw FiscalValidationException(
        'A chave pública RSA do certificado é inválida.',
        code: 'INVALID_RSA_PUBLIC_KEY',
        cause: error,
      );
    }
  }

  /// Verifica uma assinatura RSA Base64 sobre texto UTF-8.
  bool verify(String data, String signatureBase64, {bool sha256 = false}) {
    final verifier = sha256
        ? RsaSha256SignatureVerifier(rsaPublicKey)
        : RsaSha1SignatureVerifier(rsaPublicKey);
    return verifier.verify(utf8.encode(data), signatureBase64);
  }

  /// Verifica se este certificado foi assinado por [issuer].
  ///
  /// A validação cobre a assinatura RSA do `TBSCertificate`, a correspondência
  /// entre `issuer` e `subject` e a validade temporal dos dois certificados.
  /// Ela não substitui a política de confiança do sistema operacional para
  /// autenticação TLS.
  bool verifyIssuedBy(Certificate issuer, {DateTime? instant}) {
    try {
      final at = instant ?? DateTime.now();
      if (!isValidAt(at) || !issuer.isValidAt(at)) return false;
      final certificate = _parsedCertificate();
      final issuerCertificate = issuer._parsedCertificate();
      if (!_sameAsn1(certificate.issuerName, issuerCertificate.subjectName)) {
        return false;
      }
      final signer = _signerForOid(certificate.signatureAlgorithmOid);
      signer.init(false, PublicKeyParameter<RSAPublicKey>(issuer.rsaPublicKey));
      return signer.verifySignature(
        Uint8List.fromList(certificate.tbs.encodedBytes!),
        RSASignature(certificate.signature),
      );
    } on Object {
      return false;
    }
  }

  /// Valida o caminho desta identidade até um certificado autoassinado ou uma
  /// âncora explicitamente confiável.
  ///
  /// [issuers] normalmente contém os intermediários extraídos do PFX.
  /// [trustAnchors] permite informar raízes confiáveis da aplicação. Quando
  /// vazio, uma raiz autoassinada precisa estar presente no caminho.
  bool verifyChain({
    Iterable<Certificate> issuers = const [],
    Iterable<Certificate> trustAnchors = const [],
    DateTime? instant,
  }) {
    final candidates = [...issuers, ...trustAnchors];
    final anchors = trustAnchors.toList(growable: false);
    var current = this;
    final visited = <String>{};
    for (var hop = 0; hop <= candidates.length; hop++) {
      final fingerprint = base64Encode(current.der);
      if (!visited.add(fingerprint)) return false;
      if (current.verifyIssuedBy(current, instant: instant)) {
        return anchors.isEmpty ||
            anchors.any((anchor) => _sameEncoded(current.der, anchor.der));
      }
      final issuer = candidates.where((candidate) {
        return !identical(candidate, current) &&
            current.verifyIssuedBy(candidate, instant: instant);
      }).firstOrNull;
      if (issuer == null) return false;
      current = issuer;
      if (anchors.any((anchor) => _sameEncoded(current.der, anchor.der))) {
        return current.verifyIssuedBy(current, instant: instant) ||
            anchors.any((anchor) => _sameEncoded(current.der, anchor.der));
      }
    }
    return false;
  }

  _ParsedCertificate _parsedCertificate() {
    final root = ASN1Parser(der).nextObject();
    if (root is! ASN1Sequence ||
        root.elements == null ||
        root.elements!.length < 3) {
      throw const FiscalValidationException(
        'O certificado X.509 possui uma estrutura inválida.',
        code: 'INVALID_X509_CERTIFICATE',
      );
    }
    final tbs = root.elements!.first;
    final signatureAlgorithm = root.elements!.elementAt(1);
    final signatureValue = root.elements!.elementAt(2);
    if (tbs is! ASN1Sequence ||
        signatureAlgorithm is! ASN1Sequence ||
        signatureValue is! ASN1BitString ||
        tbs.elements == null ||
        signatureAlgorithm.elements == null ||
        signatureValue.stringValues == null) {
      throw const FiscalValidationException(
        'O certificado X.509 possui uma estrutura inválida.',
        code: 'INVALID_X509_CERTIFICATE',
      );
    }
    final elements = tbs.elements!;
    final offset = elements.first.tag == 0xa0 ? 1 : 0;
    if (elements.length <= offset + 5) {
      throw const FiscalValidationException(
        'O certificado X.509 não contém emissor e titular.',
        code: 'INVALID_X509_CERTIFICATE',
      );
    }
    final algorithm = signatureAlgorithm.elements!.first;
    if (algorithm is! ASN1ObjectIdentifier) {
      throw const FiscalValidationException(
        'O algoritmo de assinatura X.509 é inválido.',
        code: 'INVALID_X509_SIGNATURE_ALGORITHM',
      );
    }
    return _ParsedCertificate(
      tbs: tbs,
      issuerName: elements[offset + 2],
      subjectName: elements[offset + 4],
      signatureAlgorithmOid: algorithm.objectIdentifierAsString!,
      signature: Uint8List.fromList(signatureValue.stringValues!),
    );
  }

  Signer _signerForOid(String oid) {
    if (oid == '1.2.840.113549.1.1.5') return Signer('SHA-1/RSA');
    if (oid == '1.2.840.113549.1.1.11') return Signer('SHA-256/RSA');
    throw const FiscalValidationException(
      'O algoritmo de assinatura X.509 não é suportado.',
      code: 'UNSUPPORTED_X509_SIGNATURE_ALGORITHM',
    );
  }

  bool _sameEncoded(Uint8List? left, Uint8List? right) {
    if (left == null || right == null || left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameAsn1(ASN1Object left, ASN1Object right) {
    final leftBytes = left.encodedBytes;
    final rightBytes = right.encodedBytes;
    if (leftBytes == null || rightBytes == null) return false;
    final leftLength = left.totalEncodedByteLength;
    final rightLength = right.totalEncodedByteLength;
    if (leftLength != rightLength) {
      return false;
    }
    return _sameEncoded(
      Uint8List.fromList(leftBytes.sublist(0, leftLength)),
      Uint8List.fromList(rightBytes.sublist(0, rightLength)),
    );
  }

  /// Representação PEM do certificado, compatível com `__toString()` do
  /// NFePHP.
  String get pem {
    final encoded = base64;
    final lines = <String>[];
    for (var offset = 0; offset < encoded.length; offset += 64) {
      lines.add(
        encoded.substring(offset, (offset + 64).clamp(0, encoded.length)),
      );
    }
    return '-----BEGIN CERTIFICATE-----\n'
        '${lines.join('\n')}\n'
        '-----END CERTIFICATE-----\n';
  }

  @override
  String toString() => pem;

  /// Início da validade temporal X.509 (`notBefore`).
  DateTime get notBefore => _validity().$1;

  /// Fim da validade temporal X.509 (`notAfter`).
  DateTime get notAfter => _validity().$2;

  /// Indica se o certificado está válido no instante informado.
  bool isValidAt([DateTime? instant]) {
    final value = (instant ?? DateTime.now()).toUtc();
    return !value.isBefore(notBefore.toUtc()) &&
        !value.isAfter(notAfter.toUtc());
  }

  /// Nome comum do titular, quando presente no `subject` X.509.
  String? get commonName => _subjectAttribute('2.5.4.3');

  /// Nome comum do titular, como `Certificate::getCompanyName()` do NFePHP.
  String? get companyName =>
      _subjectAttribute('2.5.4.3') ?? _subjectAttribute('2.5.4.10');

  /// Alias compatível com `Certificate::getCompanyName()`.
  String? getCompanyName() => companyName;

  /// Alias compatível com `Certificate::getValidFrom()`.
  DateTime getValidFrom() => notBefore;

  /// Alias compatível com `Certificate::getValidTo()`.
  DateTime getValidTo() => notAfter;

  /// Indica se o certificado está expirado no instante atual.
  bool isExpired() => !isValidAt();

  /// CNPJ ICP-Brasil identificado pelo OID oficial, com fallback para o
  /// atributo serial number do `subject`.
  String? getCnpj() =>
      _oidDocumentNumber('2.16.76.1.3.3', length: 14) ??
      _subjectDocumentNumber(length: 14);

  /// CPF ICP-Brasil identificado pelo OID oficial, com fallback para o
  /// atributo serial number do `subject`.
  String? getCpf() =>
      _oidDocumentNumber('2.16.76.1.3.1', length: 11) ??
      _subjectDocumentNumber(length: 11);

  /// Nome da organização/ICP informado no `subject` do certificado.
  String getICP() => _subjectAttribute('2.5.4.10') ?? '';

  /// URL de cadeia de certificação publicada no Authority Information Access.
  ///
  /// A extensão é opcional em X.509; quando ausente, retorna string vazia,
  /// preservando o comportamento escalar do NFePHP.
  String getCAurl() {
    final text = String.fromCharCodes(
      der.where((byte) => byte >= 0x20 && byte <= 0x7e),
    );
    final matches = RegExp(r'https?://[^\s]+', caseSensitive: false)
        .allMatches(text)
        .map(
          (match) => match.group(0)!.replaceFirst(RegExp(r'[\x00-\x1f].*'), ''),
        );
    for (final value in matches) {
      final normalized = value.replaceAll(RegExp(r'[\]\)>,;]+$'), '');
      if (normalized.endsWith('.p7b') || normalized.endsWith('.p7c')) {
        return normalized;
      }
    }
    return '';
  }

  /// Nome da certificadora, derivado do OU e CN do `issuer`.
  String getCSP() {
    final organizationalUnit = _distinguishedNameAttribute(
      oid: '2.5.4.11',
      relativeIndex: 2,
    );
    final commonName = _distinguishedNameAttribute(
      oid: '2.5.4.3',
      relativeIndex: 2,
    );
    if (organizationalUnit == null && commonName == null) return '';
    if (organizationalUnit == null) return commonName!;
    if (commonName == null) return organizationalUnit;
    return '$organizationalUnit - $commonName';
  }

  String? _subjectDocumentNumber({required int length}) {
    final value = _subjectAttribute('2.5.4.5');
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == length ? digits : null;
  }

  String? _oidDocumentNumber(String oid, {required int length}) {
    final marker = _oidMarker(oid);
    if (marker.isEmpty) return null;
    for (var offset = 0; offset + marker.length < _der.length; offset++) {
      var matches = true;
      for (var index = 0; index < marker.length; index++) {
        if (_der[offset + index] != marker[index]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      final end = (offset + marker.length + 160).clamp(0, _der.length);
      final printable = String.fromCharCodes(
        _der
            .sublist(offset + marker.length, end)
            .where((byte) => byte >= 0x20 && byte <= 0x7e),
      );
      final digits = RegExp(r'\d+').allMatches(printable).map((match) {
        return match.group(0)!;
      });
      for (final value in digits) {
        if (length == 11 && value.length >= 19) {
          return value.substring(8, 19);
        }
        if (value.length == length) return value;
      }
    }
    return null;
  }

  List<int> _oidMarker(String oid) {
    final parts = oid.split('.').map(int.parse).toList();
    if (parts.length < 2) return const [];
    final encoded = <int>[40 * parts[0] + parts[1]];
    for (final part in parts.skip(2)) {
      var value = part;
      final bytes = <int>[value & 0x7f];
      value >>= 7;
      while (value > 0) {
        bytes.insert(0, (value & 0x7f) | 0x80);
        value >>= 7;
      }
      encoded.addAll(bytes);
    }
    return [0x06, encoded.length, ...encoded];
  }

  String? _subjectAttribute(String oid) {
    return _distinguishedNameAttribute(oid: oid, relativeIndex: 4);
  }

  String? _distinguishedNameAttribute({
    required String oid,
    required int relativeIndex,
  }) {
    try {
      final certificate = ASN1Parser(der).nextObject();
      if (certificate is! ASN1Sequence || certificate.elements == null) {
        return null;
      }
      final tbs = certificate.elements!.first;
      if (tbs is! ASN1Sequence || tbs.elements == null) return null;
      final elements = tbs.elements!;
      var index = 0;
      if (elements.isNotEmpty && elements.first.tag == 0xa0) index++;
      // serialNumber, signature, issuer, validity, subject
      final nameIndex = index + relativeIndex;
      if (nameIndex >= elements.length) return null;
      final subject = elements[nameIndex];
      if (subject is! ASN1Sequence || subject.elements == null) return null;
      for (final set in subject.elements!) {
        final setElements = set is ASN1Set
            ? set.elements
            : set is ASN1Sequence
            ? set.elements
            : null;
        if (setElements == null) continue;
        final attributeSequences = <List<ASN1Object>>[];
        if (setElements.length >= 2) {
          attributeSequences.add(setElements);
        }
        for (final nested in setElements) {
          final nestedElements = nested is ASN1Sequence
              ? nested.elements
              : nested is ASN1Set
              ? nested.elements
              : null;
          if (nestedElements != null) {
            attributeSequences.add(nestedElements);
          }
        }
        for (final attributes in attributeSequences) {
          if (attributes.length < 2) continue;
          final identifier = attributes.first;
          if (identifier is! ASN1ObjectIdentifier ||
              identifier.objectIdentifierAsString != oid) {
            continue;
          }
          return _asn1String(attributes[1]);
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  String? _asn1String(ASN1Object object) {
    if (object is ASN1UTF8String) return object.utf8StringValue;
    if (object is ASN1PrintableString) return object.stringValue;
    if (object is ASN1TeletextString) return object.stringValue;
    if (object is ASN1BMPString) return object.stringValue;
    if (object is ASN1IA5String) return object.stringValue;
    return null;
  }

  (DateTime, DateTime) _validity() {
    try {
      final root = ASN1Parser(der).nextObject();
      if (root is! ASN1Sequence ||
          root.elements == null ||
          root.elements!.isEmpty) {
        throw const FiscalValidationException(
          'O certificado X.509 não possui uma estrutura ASN.1 válida.',
          code: 'INVALID_X509_CERTIFICATE',
        );
      }
      final tbs = root.elements!.first;
      if (tbs is! ASN1Sequence || tbs.elements == null) {
        throw const FiscalValidationException(
          'O certificado X.509 não possui TBSCertificate válido.',
          code: 'INVALID_X509_CERTIFICATE',
        );
      }
      for (final element in tbs.elements!) {
        if (element is! ASN1Sequence || element.elements?.length != 2) {
          continue;
        }
        final before = _dateFromAsn1(element.elements![0]);
        final after = _dateFromAsn1(element.elements![1]);
        if (before != null && after != null) return (before, after);
      }
    } on FiscalException {
      rethrow;
    } on Object catch (error) {
      throw FiscalValidationException(
        'Não foi possível ler a validade do certificado X.509.',
        code: 'INVALID_X509_CERTIFICATE',
        cause: error,
      );
    }
    throw const FiscalValidationException(
      'O certificado X.509 não contém o período de validade.',
      code: 'MISSING_X509_VALIDITY',
    );
  }

  DateTime? _dateFromAsn1(ASN1Object object) {
    if (object is ASN1UtcTime) return object.time;
    if (object is ASN1GeneralizedTime) return object.dateTimeValue;
    return null;
  }
}

class _ParsedCertificate {
  const _ParsedCertificate({
    required this.tbs,
    required this.issuerName,
    required this.subjectName,
    required this.signatureAlgorithmOid,
    required this.signature,
  });

  final ASN1Sequence tbs;
  final ASN1Object issuerName;
  final ASN1Object subjectName;
  final String signatureAlgorithmOid;
  final Uint8List signature;
}

/// Material de identidade lido de um contêiner PKCS#12.
///
/// O DER da chave é mantido apenas em memória. A senha do contêiner nunca é
/// armazenada. O consumidor deve convertê-lo em uma chave privada protegida
/// por um provedor de assinatura apropriado.
class PfxIdentity {
  /// Lê certificado e chave privada de um PFX/P12.
  factory PfxIdentity.fromPfx({
    required Uint8List bytes,
    required String password,
  }) {
    try {
      final reader = _PfxReader(bytes, password);
      return PfxIdentity._(
        certificate: Certificate(reader.certificateDer()),
        certificateChain: [
          for (final der in reader.certificateChainDer()) Certificate(der),
        ],
        privateKeyInfoDer: reader.privateKeyInfoDer(),
      );
    } on FiscalException {
      rethrow;
    } on Object catch (error) {
      throw FiscalValidationException(
        'Contêiner PKCS#12 inválido ou não suportado.',
        code: 'INVALID_PKCS12',
        cause: error,
      );
    }
  }

  /// Lê certificado e chave privada de um arquivo PFX/P12.
  static Future<PfxIdentity> fromPfxFile({
    required String path,
    required String password,
  }) async => PfxIdentity.fromPfx(
    bytes: await File(path).readAsBytes(),
    password: password,
  );

  PfxIdentity._({
    required this.certificate,
    required List<Certificate> certificateChain,
    required Uint8List privateKeyInfoDer,
  }) : _certificateChain = List.unmodifiable(certificateChain),
       _privateKeyInfoDer = Uint8List.fromList(privateKeyInfoDer) {
    final publicKey = certificate.rsaPublicKey;
    final privateKey = rsaPrivateKey;
    final probe = Uint8List.fromList(
      utf8.encode('FlutterFiscalLIB:PFX-key-pair-check'),
    );
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(probe) as RSASignature;
    final verifier = Signer('SHA-256/RSA')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    if (!verifier.verifySignature(probe, signature)) {
      throw const FiscalValidationException(
        'O certificado X.509 e a chave privada do PFX não correspondem.',
        code: 'CERTIFICATE_PRIVATE_KEY_MISMATCH',
      );
    }
  }

  /// Certificado X.509 do contêiner.
  final Certificate certificate;

  /// Nome comum do certificado da identidade.
  String? getCompanyName() => certificate.getCompanyName();

  /// Início da validade do certificado da identidade.
  DateTime getValidFrom() => certificate.getValidFrom();

  /// Fim da validade do certificado da identidade.
  DateTime getValidTo() => certificate.getValidTo();

  /// Indica se o certificado da identidade está expirado.
  bool isExpired() => certificate.isExpired();

  /// CNPJ ICP-Brasil do titular, quando presente.
  String? getCnpj() => certificate.getCnpj();

  /// CPF ICP-Brasil do titular, quando presente.
  String? getCpf() => certificate.getCpf();

  /// Organização/ICP do certificado.
  String getICP() => certificate.getICP();

  /// URL da cadeia de certificação, quando publicada.
  String getCAurl() => certificate.getCAurl();

  /// Certificadora identificada no issuer.
  String getCSP() => certificate.getCSP();

  /// Certificados do contêiner, começando pelo certificado da identidade.
  ///
  /// A cadeia é mantida para que o certificado cliente enviado no mTLS possa
  /// incluir intermediárias fornecidas pelo A1. A confiança das raízes
  /// continua sendo decidida pelo runtime TLS/SO do sistema.
  final List<Certificate> _certificateChain;

  /// Cópia imutável da cadeia de certificados do contêiner.
  List<Certificate> get certificateChain =>
      List.unmodifiable(_certificateChain);

  /// Chave privada no formato PKCS#8 `PrivateKeyInfo`, em memória.
  final Uint8List _privateKeyInfoDer;

  /// Chave privada PKCS#8 como cópia defensiva.
  ///
  /// A cópia evita que uma alteração feita pelo chamador corrompa a chave
  /// mantida pela identidade e usada em assinaturas/mTLS.
  Uint8List get privateKeyInfoDer => Uint8List.fromList(_privateKeyInfoDer);

  /// Converte uma chave privada RSA PKCS#8 para o tipo do provedor RSA.
  RSAPrivateKey get rsaPrivateKey {
    final sequence = ASN1Parser(_privateKeyInfoDer).nextObject();
    if (sequence is! ASN1Sequence ||
        sequence.elements == null ||
        sequence.elements!.length < 3) {
      throw const FiscalValidationException(
        'A chave privada PKCS#8 é inválida.',
        code: 'INVALID_RSA_PRIVATE_KEY',
      );
    }
    final algorithm = ASN1AlgorithmIdentifier.fromSequence(
      sequence.elements!.elementAt(1) as ASN1Sequence,
    );
    if (algorithm.algorithm.objectIdentifierAsString !=
        '1.2.840.113549.1.1.1') {
      throw const FiscalValidationException(
        'A chave privada PFX não usa RSA.',
        code: 'UNSUPPORTED_PKCS12_PRIVATE_KEY',
      );
    }
    final privateKey = sequence.elements!.elementAt(2) as ASN1OctetString;
    final rsa = ASN1Parser(privateKey.valueBytes!).nextObject();
    if (rsa is! ASN1Sequence ||
        rsa.elements == null ||
        rsa.elements!.length < 6) {
      throw const FiscalValidationException(
        'A chave privada RSA PKCS#1 é inválida.',
        code: 'INVALID_RSA_PRIVATE_KEY',
      );
    }
    BigInt value(int index) =>
        (rsa.elements!.elementAt(index) as ASN1Integer).integer!;
    return RSAPrivateKey(value(1), value(3), value(4), value(5));
  }

  /// Assina texto UTF-8 com RSA PKCS#1 v1.5 e retorna Base64.
  Future<String> sign(String content, {bool sha256 = false}) {
    final provider = sha256
        ? RsaSha256SignatureProvider(rsaPrivateKey)
        : RsaSha1SignatureProvider(rsaPrivateKey);
    return provider.sign(utf8.encode(content));
  }

  /// Verifica uma assinatura produzida pela identidade ou pelo certificado.
  bool verify(String content, String signatureBase64, {bool sha256 = false}) =>
      certificate.verify(content, signatureBase64, sha256: sha256);

  /// Verifica a cadeia de certificados fornecida pelo contêiner PKCS#12.
  bool verifyCertificateChain({
    Iterable<Certificate> trustAnchors = const [],
    DateTime? instant,
  }) => certificate.verifyChain(
    issuers: _certificateChain.skip(1),
    trustAnchors: trustAnchors,
    instant: instant,
  );
}

class _PfxReader {
  _PfxReader(this.bytes, this.password);

  final Uint8List bytes;
  final String password;

  Uint8List certificateDer() {
    for (final bag in _safeBags()) {
      if (bag.bagId.objectIdentifierAsString != '1.2.840.113549.1.12.10.1.3') {
        continue;
      }
      final certBag = ASN1CertBag.fromSequence(bag.bagValue as ASN1Sequence);
      if (certBag.certId.objectIdentifierAsString !=
          '1.2.840.113549.1.9.22.1') {
        continue;
      }
      final value = certBag.certValue;
      if (value is ASN1OctetString && value.valueBytes != null) {
        return Uint8List.fromList(value.valueBytes!);
      }
    }
    throw const FiscalValidationException(
      'Nenhum certificado X.509 foi encontrado no PKCS#12.',
      code: 'PKCS12_CERTIFICATE_NOT_FOUND',
    );
  }

  Uint8List privateKeyInfoDer() {
    for (final bag in _safeBags()) {
      if (bag.bagId.objectIdentifierAsString != '1.2.840.113549.1.12.10.1.2') {
        continue;
      }
      final encrypted = bag.bagValue;
      if (encrypted is! ASN1Sequence ||
          encrypted.elements == null ||
          encrypted.elements!.length < 2) {
        continue;
      }
      final algorithm = ASN1AlgorithmIdentifier.fromSequence(
        encrypted.elements!.first as ASN1Sequence,
      );
      final data =
          (encrypted.elements!.elementAt(1) as ASN1OctetString).valueBytes;
      if (data != null) {
        return _decryptPbe(algorithm, data);
      }
    }
    throw const FiscalValidationException(
      'Nenhuma chave privada PKCS#8 foi encontrada no PKCS#12.',
      code: 'PKCS12_PRIVATE_KEY_NOT_FOUND',
    );
  }

  List<Uint8List> certificateChainDer() {
    final result = <Uint8List>[];
    for (final bag in _safeBags()) {
      if (bag.bagId.objectIdentifierAsString != '1.2.840.113549.1.12.10.1.3') {
        continue;
      }
      final certBag = ASN1CertBag.fromSequence(bag.bagValue as ASN1Sequence);
      if (certBag.certId.objectIdentifierAsString !=
          '1.2.840.113549.1.9.22.1') {
        continue;
      }
      final value = certBag.certValue;
      if (value is ASN1OctetString && value.valueBytes != null) {
        result.add(Uint8List.fromList(value.valueBytes!));
      }
    }
    if (result.isEmpty) {
      throw const FiscalValidationException(
        'Nenhum certificado X.509 foi encontrado no PKCS#12.',
        code: 'PKCS12_CERTIFICATE_NOT_FOUND',
      );
    }
    return result;
  }

  List<ASN1SafeBag> _safeBags() {
    final root = ASN1Parser(bytes).nextObject();
    if (root is! ASN1Sequence) {
      throw const FiscalValidationException(
        'A raiz PKCS#12 deve ser uma sequência ASN.1.',
        code: 'INVALID_PKCS12',
      );
    }
    final pfx = ASN1Pfx.fromSequence(root);
    final authSafe = pfx.authSafe.content;
    if (authSafe is! ASN1OctetString || authSafe.valueBytes == null) {
      throw const FiscalValidationException(
        'O AuthenticatedSafe PKCS#12 não contém dados.',
        code: 'INVALID_PKCS12_AUTH_SAFE',
      );
    }
    if (pfx.macData != null) {
      _verifyMac(pfx.macData!, authSafe.valueBytes!);
    }
    final authenticated = ASN1Parser(authSafe.valueBytes!).nextObject();
    if (authenticated is! ASN1Sequence) {
      throw const FiscalValidationException(
        'O AuthenticatedSafe PKCS#12 é inválido.',
        code: 'INVALID_PKCS12_AUTH_SAFE',
      );
    }
    final safe = ASN1AuthenticatedSafe.fromSequence(authenticated);
    return [for (final info in safe.info) ..._safeContents(info)];
  }

  List<ASN1SafeBag> _safeContents(ASN1ContentInfo info) {
    final type = info.contentType.objectIdentifierAsString;
    if (type == '1.2.840.113549.1.7.1') {
      final content = info.content;
      if (content is! ASN1OctetString || content.valueBytes == null) {
        return const [];
      }
      final sequence = ASN1Parser(content.valueBytes!).nextObject();
      return sequence is ASN1Sequence
          ? ASN1SafeContents.fromSequence(sequence).safeBags
          : const [];
    }
    if (type == '1.2.840.113549.1.7.6') {
      final encrypted = info.content;
      if (encrypted is! ASN1Sequence ||
          encrypted.elements == null ||
          encrypted.elements!.length < 2) {
        return const [];
      }
      // EncryptedData ::= SEQUENCE { version, encryptedContentInfo, ... }.
      final encryptedInfo = ASN1EncryptedContentInfo.fromSequence(
        encrypted.elements!.elementAt(1) as ASN1Sequence,
      );
      final plain = _decryptPbe(
        encryptedInfo.contentEncryptionAlgorithm,
        encryptedInfo.encryptedContent,
      );
      final sequence = ASN1Parser(plain).nextObject();
      return sequence is ASN1Sequence
          ? ASN1SafeContents.fromSequence(sequence).safeBags
          : const [];
    }
    return const [];
  }

  Uint8List _decryptPbe(ASN1AlgorithmIdentifier algorithm, Uint8List? data) {
    if (data == null) {
      throw const FiscalValidationException(
        'O conteúdo cifrado PKCS#12 está vazio.',
        code: 'INVALID_PKCS12_CIPHER_DATA',
      );
    }
    final oid = algorithm.algorithm.objectIdentifierAsString;
    if (oid == null) {
      throw const FiscalValidationException(
        'O algoritmo de cifra PKCS#12 não possui OID.',
        code: 'INVALID_PKCS12_CIPHER',
      );
    }
    if (!{
      '1.2.840.113549.1.12.1.3',
      '1.2.840.113549.1.12.1.4',
      '1.2.840.113549.1.12.1.5',
      '1.2.840.113549.1.12.1.6',
    }.contains(oid)) {
      throw FiscalValidationException(
        'Algoritmo PKCS#12 não suportado: $oid.',
        code: 'UNSUPPORTED_PKCS12_CIPHER',
      );
    }
    final params = algorithm.parameters;
    if (params is! ASN1Sequence ||
        params.elements == null ||
        params.elements!.length < 2) {
      throw const FiscalValidationException(
        'Parâmetros de cifra PKCS#12 inválidos.',
        code: 'INVALID_PKCS12_CIPHER_PARAMETERS',
      );
    }
    final salt = (params.elements!.first as ASN1OctetString).valueBytes!;
    final iterations = (params.elements!.elementAt(1) as ASN1Integer).integer!
        .toInt();
    final passwordBytes = _pkcs12Password(password);
    final generator = PKCS12ParametersGenerator(Digest('SHA-1'))
      ..init(passwordBytes, salt, iterations);
    final isRc2 = oid.endsWith('.5') || oid.endsWith('.6');
    final keyLength = oid.endsWith('.4')
        ? 16
        : (oid.endsWith('.6') ? 5 : (isRc2 ? 16 : 24));
    final derived = generator.generateDerivedParametersWithIV(keyLength, 8);
    if (isRc2) {
      final cipher =
          PaddedBlockCipherImpl(
            PKCS7Padding(),
            CBCBlockCipher(RC2Engine()),
          )..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<RC2Parameters>, Null>(
              ParametersWithIV(
                RC2Parameters(
                  (derived.parameters as KeyParameter).key,
                  bits: oid.endsWith('.6') ? 40 : 128,
                ),
                derived.iv,
              ),
              null,
            ),
          );
      return cipher.process(data);
    }
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(DESedeEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV(derived.parameters as KeyParameter, derived.iv),
              null,
            ),
          );
    return cipher.process(data);
  }

  void _verifyMac(ASN1MacData macData, Uint8List content) {
    final oid = macData.mac.digestAlgorithm.algorithm.objectIdentifierAsString;
    if (oid == null) {
      throw const FiscalValidationException(
        'O algoritmo MAC PKCS#12 não possui OID.',
        code: 'INVALID_PKCS12_MAC',
      );
    }
    final digestName = switch (oid) {
      '1.3.14.3.2.26' => 'SHA-1',
      '2.16.840.1.101.3.4.2.1' => 'SHA-256',
      _ => throw FiscalValidationException(
        'Digest MAC PKCS#12 não suportado: $oid.',
        code: 'UNSUPPORTED_PKCS12_MAC',
      ),
    };
    final digest = Digest(digestName);
    final generator = PKCS12ParametersGenerator(digest)
      ..init(
        _pkcs12Password(password),
        macData.macSalt,
        macData.iterationCount.toInt(),
      );
    final key = generator.generateDerivedMacParameters(digest.digestSize);
    final hmac = HMac(digest, digest.byteLength)..init(key);
    hmac.update(content, 0, content.length);
    final computed = Uint8List(digest.digestSize);
    hmac.doFinal(computed, 0);
    if (!_constantTimeEquals(computed, macData.mac.digest)) {
      throw const FiscalValidationException(
        'A senha do PKCS#12 é inválida ou o contêiner foi alterado.',
        code: 'INVALID_PKCS12_PASSWORD',
      );
    }
  }

  static Uint8List _pkcs12Password(String value) {
    if (value.isEmpty) return Uint8List(0);
    final result = Uint8List((value.length + 1) * 2);
    for (var index = 0; index < value.length; index++) {
      final codeUnit = value.codeUnitAt(index);
      result[index * 2] = codeUnit >>> 8;
      result[index * 2 + 1] = codeUnit & 0xff;
    }
    return result;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

/// Escritor mínimo de PKCS#12 para identidades RSA A1.
class _PfxWriter {
  static const _minimumIterations = 2048;

  _PfxWriter({
    required this.certificate,
    required this.privateKeyInfoDer,
    required this.password,
    required this.certificateChain,
    required this.iterations,
  }) {
    if (privateKeyInfoDer.isEmpty) {
      throw const FiscalValidationException(
        'A chave privada PKCS#8 não pode ser vazia.',
        code: 'EMPTY_PRIVATE_KEY',
      );
    }
    if (iterations < _minimumIterations) {
      throw const FiscalValidationException(
        'As iterações do PKCS#12 devem ser pelo menos 2048.',
        code: 'INVALID_PKCS12_ITERATIONS',
      );
    }
  }

  final Certificate certificate;
  final Uint8List privateKeyInfoDer;
  final String password;
  final List<Certificate> certificateChain;
  final int iterations;

  Uint8List write() {
    final random = math.Random.secure();
    final keySalt = _randomBytes(random, 20);
    final macSalt = _randomBytes(random, 20);
    final encryptedKey = _encryptPrivateKey(keySalt);
    final certBags = <Uint8List>[
      _certificateBag(certificate),
      for (final item in certificateChain) _certificateBag(item),
    ];
    final keyBag = _safeBag(
      '1.2.840.113549.1.12.10.1.2',
      _explicit(0, _encryptedPrivateKeyInfo(encryptedKey, keySalt)),
    );
    final authenticatedSafe = _sequence([
      _contentInfo(_sequence(certBags)),
      _contentInfo(_sequence([keyBag])),
    ]);
    final mac = _mac(authenticatedSafe, macSalt);
    return _sequence([
      _integer(3),
      _contentInfo(authenticatedSafe),
      _sequence([
        _sequence([
          _algorithmIdentifier('1.3.14.3.2.26', _null()),
          _octet(mac),
        ]),
        _octet(macSalt),
        _integer(iterations),
      ]),
    ]);
  }

  Uint8List _encryptPrivateKey(Uint8List salt) {
    final generator = PKCS12ParametersGenerator(Digest('SHA-1'))
      ..init(_PfxReader._pkcs12Password(password), salt, iterations);
    final derived = generator.generateDerivedParametersWithIV(24, 8);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(DESedeEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV(derived.parameters as KeyParameter, derived.iv),
              null,
            ),
          );
    return cipher.process(privateKeyInfoDer);
  }

  Uint8List _mac(Uint8List content, Uint8List salt) {
    final digest = Digest('SHA-1');
    final generator = PKCS12ParametersGenerator(digest)
      ..init(_PfxReader._pkcs12Password(password), salt, iterations);
    final key = generator.generateDerivedMacParameters(digest.digestSize);
    final hmac = HMac(digest, digest.byteLength)..init(key);
    hmac.update(content, 0, content.length);
    final result = Uint8List(digest.digestSize);
    hmac.doFinal(result, 0);
    return result;
  }

  Uint8List _certificateBag(Certificate item) => _safeBag(
    '1.2.840.113549.1.12.10.1.3',
    _explicit(
      0,
      _sequence([
        _oid('1.2.840.113549.1.9.22.1'),
        _explicit(0, _octet(item.der)),
      ]),
    ),
  );

  Uint8List _encryptedPrivateKeyInfo(Uint8List encrypted, Uint8List salt) =>
      _sequence([
        _algorithmIdentifier(
          '1.2.840.113549.1.12.1.3',
          _sequence([_octet(salt), _integer(iterations)]),
        ),
        _octet(encrypted),
      ]);

  Uint8List _safeBag(String bagId, Uint8List bagValue) =>
      _sequence([_oid(bagId), bagValue]);

  Uint8List _contentInfo(Uint8List content) =>
      _sequence([_oid('1.2.840.113549.1.7.1'), _explicit(0, _octet(content))]);

  static Uint8List _randomBytes(math.Random random, int length) =>
      Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)),
      );

  static Uint8List _tlv(int tag, List<int> value) =>
      Uint8List.fromList([tag, ..._length(value.length), ...value]);

  static List<int> _length(int value) {
    if (value < 0x80) return [value];
    final bytes = <int>[];
    var remaining = value;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }
    return [0x80 | bytes.length, ...bytes];
  }

  static Uint8List _sequence(Iterable<Uint8List> values) =>
      _tlv(0x30, _concat(values));

  static Uint8List _explicit(int tag, Uint8List value) =>
      _tlv(0xa0 | tag, value);

  static Uint8List _octet(List<int> value) => _tlv(0x04, value);

  static Uint8List _null() => Uint8List.fromList([0x05, 0x00]);

  static Uint8List _integer(int value) {
    if (value == 0) return Uint8List.fromList([0x02, 0x01, 0x00]);
    final bytes = <int>[];
    var remaining = value;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }
    if (bytes.first & 0x80 != 0) bytes.insert(0, 0);
    return _tlv(0x02, bytes);
  }

  static Uint8List _algorithmIdentifier(String oid, Uint8List parameters) =>
      _sequence([_oid(oid), parameters]);

  static Uint8List _oid(String value) {
    final parts = value.split('.').map(int.parse).toList();
    final encoded = <int>[40 * parts[0] + parts[1]];
    for (final part in parts.skip(2)) {
      var remaining = part;
      final bytes = <int>[remaining & 0x7f];
      remaining >>= 7;
      while (remaining > 0) {
        bytes.insert(0, (remaining & 0x7f) | 0x80);
        remaining >>= 7;
      }
      encoded.addAll(bytes);
    }
    return _tlv(0x06, encoded);
  }

  static List<int> _concat(Iterable<Uint8List> values) => [
    for (final value in values) ...value,
  ];
}
