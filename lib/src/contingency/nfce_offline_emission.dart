import 'package:xml/xml.dart';

import '../crypto/xml_signature_service.dart';
import '../exceptions/fiscal_exception.dart';
import '../models/contingency.dart';
import '../models/nfe_document.dart';
import '../models/nfce_supplement.dart';
import '../validation/nfce_qr_code.dart';
import '../xml/nfe_xml_builder.dart';

/// Resultado da preparação de uma NFC-e offline assinada.
class NfceOfflineEmission {
  /// Cria o resultado da emissão local.
  const NfceOfflineEmission({required this.signedXml, required this.qrCode});

  /// XML assinado pronto para persistência e impressão.
  final String signedXml;

  /// Payload/URL do QR Code de contingência.
  final NfceQrCodePayload qrCode;
}

/// Coordena montagem, assinatura, digest e QR Code de contingência offline.
class NfceOfflineEmissionService {
  /// Cria o serviço usando o builder e assinador fornecidos.
  const NfceOfflineEmissionService({
    required this.signer,
    this.builder = const NfeXmlBuilder(),
  });

  /// Assinador XML configurado com certificado do emitente.
  final XmlSignatureService signer;

  /// Builder fiscal usado para gerar o XML sem suplemento.
  final NfeXmlBuilder builder;

  /// Monta e assina a NFC-e e acrescenta o QR Code offline.
  Future<NfceOfflineEmission> prepare({
    required NfeDocument document,
    int? cscId,
    String? csc,
    required String baseUrl,
    int qrCodeVersion = 2,
  }) async {
    if (document.model != 65 ||
        document.contingency?.mode != ContingencyMode.offlineNfce) {
      throw const FiscalValidationException(
        'A emissão offline exige NFC-e modelo 65 com tpEmis=9.',
        code: 'INVALID_OFFLINE_EMISSION_CONTEXT',
      );
    }
    if (document.nfceSupplement != null) {
      throw const FiscalValidationException(
        'O suplemento NFC-e é gerado pelo serviço offline.',
        code: 'DUPLICATE_NFCE_SUPPLEMENT',
      );
    }
    final unsigned = builder.buildStrict(document);
    final signed = await signer.sign(unsigned);
    final digest = signer.digestValue(signed);
    if (digest == null) {
      throw const FiscalValidationException(
        'A assinatura não contém DigestValue.',
        code: 'MISSING_SIGNATURE_DIGEST',
      );
    }
    final NfceQrCodePayload qrCode;
    if (qrCodeVersion == 2) {
      if (cscId == null || csc == null) {
        throw const FiscalValidationException(
          'O QR Code 2.00 offline exige identificador e CSC.',
          code: 'INVALID_CSC',
        );
      }
      qrCode = NfceQrCode.offline(
        accessKey: document.accessKey,
        environment: document.environment,
        issueDate: document.issueDate,
        total: document.total,
        digestValue: digest,
        cscId: cscId,
        csc: csc,
        baseUrl: baseUrl,
      );
    } else if (qrCodeVersion == 3) {
      if (signer.algorithm != XmlSignatureAlgorithm.sha1) {
        throw const FiscalValidationException(
          'O QR Code 3.00 offline exige assinatura RSA-SHA1 nos parâmetros.',
          code: 'INVALID_QR_CODE_SIGNATURE_ALGORITHM',
        );
      }
      qrCode = await NfceQrCode.offlineV3(
        accessKey: document.accessKey,
        environment: document.environment,
        issueDate: document.issueDate,
        total: document.total,
        recipientTaxId: document.recipient?.taxId,
        signatureProvider: signer.provider,
        baseUrl: baseUrl,
      );
    } else {
      throw const FiscalValidationException(
        'A versão do QR Code NFC-e deve ser 2 ou 3.',
        code: 'INVALID_QR_CODE_VERSION',
      );
    }
    final supplement = NfceXmlSupplement(qrCode: qrCode.url, keyUrl: baseUrl);
    final signedDocument = XmlDocument.parse(signed);
    final root = signedDocument.rootElement;
    final signature = root.getElement('Signature');
    if (signature == null) {
      throw const FiscalValidationException(
        'A assinatura não foi anexada à NFC-e.',
        code: 'MISSING_XML_SIGNATURE',
      );
    }
    final supplementElement = XmlElement(
      XmlName.parts('infNFeSupl'),
      const [],
      [
        XmlElement(XmlName.parts('qrCode'), const [], [
          XmlText(supplement.qrCode),
        ]),
        XmlElement(XmlName.parts('urlChave'), const [], [
          XmlText(supplement.keyUrl),
        ]),
      ],
    );
    final position = root.children.indexOf(signature);
    root.children.insert(position, supplementElement);
    return NfceOfflineEmission(
      signedXml: signedDocument.toXmlString(pretty: false),
      qrCode: qrCode,
    );
  }
}
