import 'dart:convert';

import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import 'certificate.dart';
import 'rsa_signature.dart';
import 'xml_canonicalizer.dart';
import 'xml_digest.dart';

/// Perfil criptográfico usado no XMLDSig.
enum XmlSignatureAlgorithm {
  /// Perfil fiscal fixado pelos schemas NF-e/NFC-e PL_010b.
  sha1,

  /// Perfil moderno mantido para compatibilidade e integrações genéricas.
  sha256,
}

/// Produz uma assinatura XML enveloped com SHA-256 e provedor RSA injetado.
///
/// A camada usa canonicalização XML inclusiva C14N 1.0 para o digest e
/// `SignedInfo`; validação XSD e política fiscal do ambiente continuam sendo
/// responsabilidades da etapa de autorização.
class XmlSignatureService {
  /// Cria o serviço com um provedor de assinatura e certificado opcional.
  XmlSignatureService(
    this.provider, {
    this.certificateBase64,
    this.algorithm = XmlSignatureAlgorithm.sha256,
  });

  /// Cria o serviço diretamente com uma identidade A1 PKCS#12 já carregada.
  factory XmlSignatureService.fromPfx(
    PfxIdentity identity, {
    XmlSignatureAlgorithm algorithm = XmlSignatureAlgorithm.sha1,
  }) {
    if (!identity.certificate.isValidAt()) {
      throw const FiscalValidationException(
        'O certificado A1 está fora do período de validade.',
        code: 'EXPIRED_CERTIFICATE',
      );
    }
    return XmlSignatureService(
      algorithm == XmlSignatureAlgorithm.sha1
          ? RsaSha1SignatureProvider(identity.rsaPrivateKey)
          : RsaSha256SignatureProvider(identity.rsaPrivateKey),
      certificateBase64: identity.certificate.base64,
      algorithm: algorithm,
    );
  }

  /// Provedor que protege a chave privada e assina o `SignedInfo`.
  final XmlSignatureProvider provider;

  /// Certificado X.509 DER em Base64 para inclusão em `KeyInfo`.
  final String? certificateBase64;

  /// Perfil de digest/assinatura emitido no `SignedInfo`.
  final XmlSignatureAlgorithm algorithm;

  /// Assina o XML e retorna a representação serializada.
  Future<String> sign(String xml) async {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    final infs = _directElements(root, 'infNFe').toList();
    if (root.localName != 'NFe' || infs.length != 1) {
      throw const FiscalValidationException(
        'O XML deve possuir a raiz NFe e o grupo infNFe.',
        code: 'INVALID_XML_FOR_SIGNATURE',
      );
    }
    final inf = infs.single;
    if (document.descendants.whereType<XmlElement>().any(
      (element) => element.localName == 'Signature',
    )) {
      throw const FiscalValidationException(
        'O XML já possui uma assinatura.',
        code: 'XML_ALREADY_SIGNED',
      );
    }
    final id = inf.getAttribute('Id');
    if (id == null || id.isEmpty) {
      throw const FiscalValidationException(
        'O grupo infNFe precisa do atributo Id para ser assinado.',
        code: 'MISSING_XML_SIGNATURE_ID',
      );
    }
    final payload = XmlCanonicalizer.canonicalize(
      inf,
      inheritedNamespaces: {
        '': root.getAttribute('xmlns') ?? 'http://www.portalfiscal.inf.br/nfe',
      },
    );
    final digest = XmlDigest.base64(payload, algorithm: _digestAlgorithm);
    final signedInfo = _signedInfo(id, digest);
    final canonicalSignedInfo = XmlCanonicalizer.canonicalize(
      XmlDocument.parse(signedInfo).rootElement,
    );
    final signatureValue = await provider.sign(
      utf8.encode(canonicalSignedInfo),
    );
    final signature = XmlDocument.parse(
      '''<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  $signedInfo
  <SignatureValue>$signatureValue</SignatureValue>
  ${certificateBase64 == null ? '' : '<KeyInfo><X509Data><X509Certificate>$certificateBase64</X509Certificate></X509Data></KeyInfo>'}
</Signature>''',
    ).rootElement;
    root.children.add(signature.copy());
    // A saída assinada deve preservar exatamente os bytes lógicos usados no
    // digest; pretty-printing adicionaria whitespace após a assinatura.
    return document.toXmlString(pretty: false);
  }

  /// Assina um `envEvento`, anexando a assinatura dentro de `evento` após
  /// `infEvento`, conforme os schemas de eventos da NF-e.
  Future<String> signEvent(String xml) async {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    final events = _directElements(root, 'evento').toList();
    final event = events.length == 1 ? events.single : null;
    final infs = event == null
        ? const <XmlElement>[]
        : _directElements(event, 'infEvento').toList();
    final inf = infs.length == 1 ? infs.single : null;
    if (root.localName != 'envEvento' || event == null || inf == null) {
      throw const FiscalValidationException(
        'O XML deve possuir a raiz envEvento e o grupo infEvento.',
        code: 'INVALID_EVENT_XML_FOR_SIGNATURE',
      );
    }
    if (document.descendants.whereType<XmlElement>().any(
      (element) => element.localName == 'Signature',
    )) {
      throw const FiscalValidationException(
        'O evento já possui uma assinatura.',
        code: 'EVENT_XML_ALREADY_SIGNED',
      );
    }
    final id = inf.getAttribute('Id');
    if (id == null || id.isEmpty) {
      throw const FiscalValidationException(
        'O grupo infEvento precisa do atributo Id para ser assinado.',
        code: 'MISSING_EVENT_SIGNATURE_ID',
      );
    }
    final payload = XmlCanonicalizer.canonicalize(
      inf,
      inheritedNamespaces: {
        '': root.getAttribute('xmlns') ?? 'http://www.portalfiscal.inf.br/nfe',
      },
    );
    final digest = XmlDigest.base64(payload, algorithm: _digestAlgorithm);
    final signedInfo = _signedInfo(id, digest);
    final canonicalSignedInfo = XmlCanonicalizer.canonicalize(
      XmlDocument.parse(signedInfo).rootElement,
    );
    final signatureValue = await provider.sign(
      utf8.encode(canonicalSignedInfo),
    );
    final signature = XmlDocument.parse(
      '''<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  $signedInfo
  <SignatureValue>$signatureValue</SignatureValue>
  ${certificateBase64 == null ? '' : '<KeyInfo><X509Data><X509Certificate>$certificateBase64</X509Certificate></X509Data></KeyInfo>'}
</Signature>''',
    ).rootElement;
    event.children.add(signature.copy());
    return document.toXmlString(pretty: false);
  }

  /// Assina um pedido `inutNFe`, anexando a assinatura após `infInut`.
  Future<String> signInutilization(String xml) async {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    final infs = _directElements(root, 'infInut').toList();
    if (root.localName != 'inutNFe' || infs.length != 1) {
      throw const FiscalValidationException(
        'O XML deve possuir a raiz inutNFe e o grupo infInut.',
        code: 'INVALID_INUTILIZATION_XML_FOR_SIGNATURE',
      );
    }
    final inf = infs.single;
    if (document.descendants.whereType<XmlElement>().any(
      (element) => element.localName == 'Signature',
    )) {
      throw const FiscalValidationException(
        'A inutilização já possui uma assinatura.',
        code: 'INUTILIZATION_XML_ALREADY_SIGNED',
      );
    }
    final id = inf.getAttribute('Id');
    if (id == null || id.isEmpty) {
      throw const FiscalValidationException(
        'O grupo infInut precisa do atributo Id para ser assinado.',
        code: 'MISSING_INUTILIZATION_SIGNATURE_ID',
      );
    }
    final digest = XmlDigest.base64(
      XmlCanonicalizer.canonicalize(
        inf,
        inheritedNamespaces: {
          '':
              root.getAttribute('xmlns') ??
              'http://www.portalfiscal.inf.br/nfe',
        },
      ),
      algorithm: _digestAlgorithm,
    );
    final signedInfo = _signedInfo(id, digest);
    final signatureValue = await provider.sign(
      utf8.encode(
        XmlCanonicalizer.canonicalize(
          XmlDocument.parse(signedInfo).rootElement,
        ),
      ),
    );
    final signature = XmlDocument.parse(
      '''<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  $signedInfo
  <SignatureValue>$signatureValue</SignatureValue>
  ${certificateBase64 == null ? '' : '<KeyInfo><X509Data><X509Certificate>$certificateBase64</X509Certificate></X509Data></KeyInfo>'}
</Signature>''',
    ).rootElement;
    root.children.add(signature.copy());
    return document.toXmlString(pretty: false);
  }

  /// Verifica se o `DigestValue` da assinatura corresponde ao `infNFe` atual.
  bool verifyDigest(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final root = document.rootElement;
      if (root.localName != 'NFe') return false;
      final infs = _directElements(root, 'infNFe');
      final signatures = _directElements(root, 'Signature');
      if (infs.length != 1 || signatures.length != 1) return false;
      if (document.descendants
              .whereType<XmlElement>()
              .where((element) => element.localName == 'Signature')
              .length !=
          1) {
        return false;
      }
      final inf = infs.single;
      final signature = signatures.single;
      final id = inf.getAttribute('Id');
      final reference = signature
          .getElement('SignedInfo')
          ?.getElement('Reference');
      final expected = reference?.getElement('DigestValue')?.innerText.trim();
      if (id == null ||
          id.isEmpty ||
          reference == null ||
          reference.getAttribute('URI') != '#$id' ||
          expected == null ||
          expected.isEmpty) {
        return false;
      }
      final referencedIds = document.descendants.whereType<XmlElement>().where(
        (element) => element.getAttribute('Id') == id,
      );
      if (referencedIds.length != 1) return false;
      final signatureAlgorithm = _signatureAlgorithmFromSignature(signature);
      if (signatureAlgorithm == null) return false;
      if (signatureAlgorithm != algorithm) return false;
      final digestAlgorithm = _digestAlgorithmFromSignature(signatureAlgorithm);
      return XmlDigest.base64(
            XmlCanonicalizer.canonicalize(
              inf,
              inheritedNamespaces: {
                '':
                    document.rootElement.getAttribute('xmlns') ??
                    'http://www.portalfiscal.inf.br/nfe',
              },
            ),
            algorithm: digestAlgorithm,
          ) ==
          expected;
    } on XmlException {
      return false;
    }
  }

  /// Retorna o `DigestValue` Base64 da assinatura enveloped.
  ///
  /// O valor é usado pelo perfil QR Code 2.00 de contingência offline.
  String? digestValue(String signedXml) {
    try {
      final document = XmlDocument.parse(signedXml);
      final signature = document.rootElement.getElement('Signature');
      final value = signature
          ?.getElement('SignedInfo')
          ?.getElement('Reference')
          ?.getElement('DigestValue')
          ?.innerText
          .trim();
      return value == null || value.isEmpty ? null : value;
    } on XmlException {
      return null;
    }
  }

  /// Verifica digest e `SignatureValue` RSA-SHA256 de uma assinatura.
  ///
  /// A estrutura é deliberadamente restritiva: somente um `infNFe` e uma
  /// `Signature` como filhos diretos de `NFe` são aceitos, e a referência deve
  /// apontar exatamente para o `Id` do `infNFe`. Isso evita aceitar uma
  /// assinatura válida anexada a um elemento fiscal diferente (wrapping).
  bool verifySignature(String xml, XmlSignatureVerifier verifier) {
    try {
      final document = XmlDocument.parse(xml);
      final root = document.rootElement;
      if (root.localName != 'NFe') return false;
      final children = root.children.whereType<XmlElement>();
      final infs = children.where((element) => element.localName == 'infNFe');
      final signatures = children.where(
        (element) => element.localName == 'Signature',
      );
      if (infs.length != 1 || signatures.length != 1) return false;
      final inf = infs.single;
      final signature = signatures.single;
      final id = inf.getAttribute('Id');
      final signedInfo = signature.getElement('SignedInfo');
      if (signedInfo == null) return false;
      final reference = signedInfo.getElement('Reference');
      final signatureValue = signature.getElement('SignatureValue')?.innerText;
      if (id == null || reference == null) return false;
      if (reference.getAttribute('URI') != '#$id' ||
          signatureValue == null ||
          signatureValue.trim().isEmpty) {
        return false;
      }
      final referencedIds = document.descendants.whereType<XmlElement>().where(
        (element) => element.getAttribute('Id') == id,
      );
      if (referencedIds.length != 1 || !verifyDigest(xml)) return false;
      if (_signatureAlgorithmFromSignature(signature) != algorithm) {
        return false;
      }
      final canonicalSignedInfo = XmlCanonicalizer.canonicalize(signedInfo);
      return verifier.verify(
        utf8.encode(canonicalSignedInfo),
        signatureValue.trim(),
      );
    } on XmlException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Verifica o digest e a assinatura RSA de um `envEvento` sem aceitar
  /// referências ambíguas a outro `infEvento`.
  bool verifyEventSignature(String xml, XmlSignatureVerifier verifier) {
    try {
      final document = XmlDocument.parse(xml);
      final root = document.rootElement;
      final events = _directElements(root, 'evento').toList();
      final event = events.length == 1 ? events.single : null;
      final infs = event == null
          ? const <XmlElement>[]
          : _directElements(event, 'infEvento').toList();
      final inf = infs.length == 1 ? infs.single : null;
      final signatures = event == null
          ? null
          : _directElements(event, 'Signature').toList();
      if (root.localName != 'envEvento' ||
          event == null ||
          inf == null ||
          signatures == null ||
          signatures.length != 1) {
        return false;
      }
      if (document.descendants
              .whereType<XmlElement>()
              .where((element) => element.localName == 'Signature')
              .length !=
          1) {
        return false;
      }
      final signature = signatures.single;
      final id = inf.getAttribute('Id');
      final signedInfo = signature.getElement('SignedInfo');
      final reference = signedInfo?.getElement('Reference');
      final signatureValue = signature.getElement('SignatureValue')?.innerText;
      if (id == null ||
          signedInfo == null ||
          reference == null ||
          reference.getAttribute('URI') != '#$id' ||
          signatureValue == null ||
          signatureValue.trim().isEmpty) {
        return false;
      }
      final referencedIds = document.descendants.whereType<XmlElement>().where(
        (element) => element.getAttribute('Id') == id,
      );
      if (referencedIds.length != 1) return false;
      final signatureAlgorithm = _signatureAlgorithmFromSignature(signature);
      if (signatureAlgorithm == null) return false;
      if (signatureAlgorithm != algorithm) return false;
      final digestAlgorithm = _digestAlgorithmFromSignature(signatureAlgorithm);
      final digest = XmlDigest.base64(
        XmlCanonicalizer.canonicalize(
          inf,
          inheritedNamespaces: {
            '':
                root.getAttribute('xmlns') ??
                'http://www.portalfiscal.inf.br/nfe',
          },
        ),
        algorithm: digestAlgorithm,
      );
      if (digest != reference.getElement('DigestValue')?.innerText.trim()) {
        return false;
      }
      return verifier.verify(
        utf8.encode(XmlCanonicalizer.canonicalize(signedInfo)),
        signatureValue.trim(),
      );
    } on XmlException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Verifica uma assinatura XMLDSig de `inutNFe/infInut`.
  bool verifyInutilizationSignature(String xml, XmlSignatureVerifier verifier) {
    try {
      final document = XmlDocument.parse(xml);
      final root = document.rootElement;
      final infs = _directElements(root, 'infInut').toList();
      final signatures = _directElements(root, 'Signature').toList();
      final inf = infs.length == 1 ? infs.single : null;
      final signature = signatures.length == 1 ? signatures.single : null;
      final id = inf?.getAttribute('Id');
      final signedInfo = signature?.getElement('SignedInfo');
      final reference = signedInfo?.getElement('Reference');
      final value = signature?.getElement('SignatureValue')?.innerText;
      if (root.localName != 'inutNFe' ||
          inf == null ||
          signature == null ||
          id == null ||
          signedInfo == null ||
          reference == null ||
          reference.getAttribute('URI') != '#$id' ||
          value == null ||
          value.trim().isEmpty) {
        return false;
      }
      if (document.descendants
              .whereType<XmlElement>()
              .where((element) => element.localName == 'Signature')
              .length !=
          1) {
        return false;
      }
      final referencedIds = document.descendants.whereType<XmlElement>().where(
        (element) => element.getAttribute('Id') == id,
      );
      if (referencedIds.length != 1) return false;
      final signatureAlgorithm = _signatureAlgorithmFromSignature(signature);
      if (signatureAlgorithm == null) return false;
      if (signatureAlgorithm != algorithm) return false;
      final digest = XmlDigest.base64(
        XmlCanonicalizer.canonicalize(
          inf,
          inheritedNamespaces: {
            '':
                root.getAttribute('xmlns') ??
                'http://www.portalfiscal.inf.br/nfe',
          },
        ),
        algorithm: _digestAlgorithmFromSignature(signatureAlgorithm),
      );
      if (digest != reference.getElement('DigestValue')?.innerText.trim()) {
        return false;
      }
      return verifier.verify(
        utf8.encode(XmlCanonicalizer.canonicalize(signedInfo)),
        value.trim(),
      );
    } on XmlException {
      return false;
    } on FormatException {
      return false;
    }
  }

  String _signedInfo(String id, String digest) =>
      '''<SignedInfo xmlns="http://www.w3.org/2000/09/xmldsig#">
  <CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
  <SignatureMethod Algorithm="$_signatureMethodUri"/>
  <Reference URI="#$id">
    <Transforms>
      <Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
      <Transform Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
    </Transforms>
    <DigestMethod Algorithm="$_digestMethodUri"/>
    <DigestValue>$digest</DigestValue>
  </Reference>
</SignedInfo>''';

  XmlDigestAlgorithm get _digestAlgorithm =>
      algorithm == XmlSignatureAlgorithm.sha1
      ? XmlDigestAlgorithm.sha1
      : XmlDigestAlgorithm.sha256;

  String get _signatureMethodUri => algorithm == XmlSignatureAlgorithm.sha1
      ? 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
      : 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256';

  String get _digestMethodUri => algorithm == XmlSignatureAlgorithm.sha1
      ? 'http://www.w3.org/2000/09/xmldsig#sha1'
      : 'http://www.w3.org/2001/04/xmlenc#sha256';

  XmlSignatureAlgorithm? _signatureAlgorithmFromSignature(
    XmlElement signature,
  ) {
    final signedInfo = signature.getElement('SignedInfo');
    final signatureUri = signedInfo
        ?.getElement('SignatureMethod')
        ?.getAttribute('Algorithm');
    final digestUri = signedInfo
        ?.getElement('Reference')
        ?.getElement('DigestMethod')
        ?.getAttribute('Algorithm');
    if (signatureUri == 'http://www.w3.org/2000/09/xmldsig#rsa-sha1' &&
        digestUri == 'http://www.w3.org/2000/09/xmldsig#sha1') {
      return XmlSignatureAlgorithm.sha1;
    }
    if (signatureUri == 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256' &&
        digestUri == 'http://www.w3.org/2001/04/xmlenc#sha256') {
      return XmlSignatureAlgorithm.sha256;
    }
    return null;
  }

  XmlDigestAlgorithm _digestAlgorithmFromSignature(
    XmlSignatureAlgorithm signatureAlgorithm,
  ) => signatureAlgorithm == XmlSignatureAlgorithm.sha1
      ? XmlDigestAlgorithm.sha1
      : XmlDigestAlgorithm.sha256;

  Iterable<XmlElement> _directElements(XmlElement parent, String localName) =>
      parent.childElements.where((element) => element.localName == localName);
}
