import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../crypto/xml_digest.dart';
import '../models/access_key.dart';
import '../tools.dart';

/// Gera os payloads do QR Code 2.00 da NFC-e.
///
/// A classe produz o valor do parâmetro `p` conforme o Manual de
/// Especificações Técnicas do DANFE NFC-e e QR Code. A URL base é fornecida
/// pela UF, pois os endpoints não são uniformes entre as administrações
/// tributárias.
class NfceQrCode {
  NfceQrCode._();

  /// Injeta `infNFeSupl` em uma NFC-e já assinada.
  ///
  /// O suplemento é inserido fora de `infNFe`, antes de `Signature`, portanto
  /// não altera o trecho coberto pela assinatura XMLDSig. O XML precisa ter
  /// sido assinado previamente; esta função não assina nem substitui um
  /// suplemento existente.
  static String injectIntoXml({
    required String signedXml,
    required NfceQrCodePayload payload,
    String keyUrl = '',
  }) {
    final document = _parseXml(signedXml);
    final nfe = _find(document.rootElement, 'NFe');
    final infNfe = _find(nfe, 'infNFe');
    final model = _find(infNfe, 'mod').innerText.trim();
    if (model != '65') {
      throw const FiscalValidationException(
        'O XML do QR Code deve ser uma NFC-e modelo 65.',
        code: 'INVALID_NFCE_XML_MODEL',
      );
    }
    if (_findOptional(nfe, 'infNFeSupl') != null) {
      throw const FiscalValidationException(
        'O XML já possui infNFeSupl; a injeção seria duplicada.',
        code: 'DUPLICATE_NFCE_SUPPLEMENT',
      );
    }
    final signatureIndex = nfe.children.indexWhere(
      (node) => node is XmlElement && node.localName == 'Signature',
    );
    if (signatureIndex < 0) {
      throw const FiscalValidationException(
        'A NFC-e deve estar assinada antes da injeção do QR Code.',
        code: 'MISSING_XML_SIGNATURE',
      );
    }
    final supplement = XmlElement(XmlName.parts('infNFeSupl'), const [], [
      XmlElement(XmlName.parts('qrCode'), const [], [XmlText(payload.url)]),
      XmlElement(XmlName.parts('urlChave'), const [], [XmlText(keyUrl)]),
    ]);
    nfe.children.insert(signatureIndex, supplement);
    return document.toXmlString(pretty: false);
  }

  /// Monta o payload e a URL do QR Code para emissão online.
  ///
  /// O hash é SHA-1 em hexadecimal sobre
  /// `chave|2|tpAmb|idCSC|CSC`.
  static NfceQrCodePayload online({
    required String accessKey,
    required int environment,
    required int cscId,
    required String csc,
    required String baseUrl,
  }) {
    _validateCommon(
      accessKey: accessKey,
      environment: environment,
      cscId: cscId,
      csc: csc,
      baseUrl: baseUrl,
    );
    final data = '$accessKey|2|$environment|$cscId';
    final hash = _sha1Hex('$data$csc');
    return NfceQrCodePayload._(data: '$data|$hash', baseUrl: baseUrl);
  }

  /// Monta o QR Code 3.00 para NFC-e emitida online.
  ///
  /// O leiaute 3.00 não usa CSC nem hash: os parâmetros são
  /// `chave|3|tpAmb`, conforme o Manual DANFE NFC-e 6.0.
  static NfceQrCodePayload onlineV3({
    required String accessKey,
    required int environment,
    required String baseUrl,
  }) {
    _validateV3Common(
      accessKey: accessKey,
      environment: environment,
      baseUrl: baseUrl,
    );
    return NfceQrCodePayload._(
      data: '$accessKey|3|$environment',
      baseUrl: baseUrl,
    );
  }

  /// Monta o payload e a URL do QR Code para contingência offline.
  ///
  /// [digestValue] é o `DigestValue` XML em Base64. O padrão exige sua
  /// conversão para hexadecimal antes da composição do hash SHA-1:
  /// `chave|2|tpAmb|dia|vNF|digValHex|idCSC|CSC`.
  static NfceQrCodePayload offline({
    required String accessKey,
    required int environment,
    required DateTime issueDate,
    required num total,
    required String digestValue,
    required int cscId,
    required String csc,
    required String baseUrl,
  }) {
    _validateCommon(
      accessKey: accessKey,
      environment: environment,
      cscId: cscId,
      csc: csc,
      baseUrl: baseUrl,
    );
    if (total < 0 || !total.isFinite) {
      throw const FiscalValidationException(
        'O valor total da NFC-e deve ser finito e não negativo.',
        code: 'INVALID_NFCE_TOTAL',
      );
    }
    _assertBase64Shape(digestValue);
    // O manual especifica a conversão hexadecimal da representação textual
    // do DigestValue (os caracteres Base64), e não a decodificação do digest.
    final digestHex = _hex(utf8.encode(digestValue));
    final data = [
      accessKey,
      '2',
      '$environment',
      issueDate.day.toString().padLeft(2, '0'),
      Tools.formatDecimal(total),
      digestHex,
      '$cscId',
    ].join('|');
    final hash = _sha1Hex('$data$csc');
    return NfceQrCodePayload._(data: '$data|$hash', baseUrl: baseUrl);
  }

  /// Monta o QR Code 3.00 para NFC-e em contingência offline.
  ///
  /// A assinatura cobre exatamente os sete primeiros parâmetros, separados
  /// por `|`, e deve usar o mesmo certificado da NFC-e (RSA-SHA1 no perfil
  /// fiscal). Quando o consumidor não é identificado, [recipientTaxId] deve
  /// ser nulo e os dois campos correspondentes permanecem vazios.
  static Future<NfceQrCodePayload> offlineV3({
    required String accessKey,
    required int environment,
    required DateTime issueDate,
    required num total,
    String? recipientTaxId,
    int? recipientType,
    required XmlSignatureProvider signatureProvider,
    required String baseUrl,
  }) async {
    _validateV3Common(
      accessKey: accessKey,
      environment: environment,
      baseUrl: baseUrl,
    );
    if (total < 0 || !total.isFinite) {
      throw const FiscalValidationException(
        'O valor total da NFC-e deve ser finito e não negativo.',
        code: 'INVALID_NFCE_TOTAL',
      );
    }
    final recipient = _recipientV3(taxId: recipientTaxId, type: recipientType);
    final data = [
      accessKey,
      '3',
      '$environment',
      issueDate.day.toString().padLeft(2, '0'),
      Tools.formatDecimal(total),
      recipient.type ?? '',
      recipient.id ?? '',
    ].join('|');
    final signature = await signatureProvider.sign(utf8.encode(data));
    if (signature.trim().isEmpty || signature.contains(RegExp(r'\s'))) {
      throw const FiscalValidationException(
        'A assinatura do QR Code 3.00 deve ser Base64 em uma única linha.',
        code: 'INVALID_QR_CODE_SIGNATURE',
      );
    }
    try {
      base64Decode(signature);
    } on FormatException {
      throw const FiscalValidationException(
        'A assinatura do QR Code 3.00 deve ser Base64 válida.',
        code: 'INVALID_QR_CODE_SIGNATURE',
      );
    }
    return NfceQrCodePayload._(data: '$data|$signature', baseUrl: baseUrl);
  }

  static void _validateCommon({
    required String accessKey,
    required int environment,
    required int cscId,
    required String csc,
    required String baseUrl,
  }) {
    if (!AccessKey.isValid(accessKey) || AccessKey.modelOf(accessKey) != 65) {
      throw const FiscalValidationException(
        'A chave deve ser válida e pertencer a uma NFC-e modelo 65.',
        code: 'INVALID_NFCE_ACCESS_KEY',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente deve ser 1 ou 2.',
        code: 'INVALID_ENVIRONMENT',
      );
    }
    if (cscId < 1 || csc.trim().isEmpty) {
      throw const FiscalValidationException(
        'O identificador e o CSC são obrigatórios.',
        code: 'INVALID_CSC',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FiscalValidationException(
        'A URL base do QR Code deve possuir esquema.',
        code: 'INVALID_QR_CODE_URL',
      );
    }
  }

  static void _validateV3Common({
    required String accessKey,
    required int environment,
    required String baseUrl,
  }) {
    if (!AccessKey.isValid(accessKey) || AccessKey.modelOf(accessKey) != 65) {
      throw const FiscalValidationException(
        'A chave deve ser válida e pertencer a uma NFC-e modelo 65.',
        code: 'INVALID_NFCE_ACCESS_KEY',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente deve ser 1 ou 2.',
        code: 'INVALID_ENVIRONMENT',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FiscalValidationException(
        'A URL base do QR Code deve possuir esquema.',
        code: 'INVALID_QR_CODE_URL',
      );
    }
  }

  static ({String? type, String? id}) _recipientV3({
    required String? taxId,
    required int? type,
  }) {
    if (taxId == null || taxId.trim().isEmpty) {
      if (type != null) {
        throw const FiscalValidationException(
          'O tipo do destinatário exige sua identificação.',
          code: 'INVALID_QR_CODE_RECIPIENT',
        );
      }
      return (type: null, id: null);
    }
    final normalized = taxId.trim();
    final digits = Tools.onlyDigits(normalized);
    final resolvedType =
        type ??
        switch (digits.length) {
          11 => 2,
          14 => 1,
          _ => null,
        };
    if (resolvedType == null || !const [1, 2, 3].contains(resolvedType)) {
      throw const FiscalValidationException(
        'O tipo do destinatário do QR Code 3.00 é inválido.',
        code: 'INVALID_QR_CODE_RECIPIENT',
      );
    }
    final id = resolvedType == 3 ? normalized : digits;
    if ((resolvedType == 1 && !Tools.isValidCnpj(id)) ||
        (resolvedType == 2 && !Tools.isValidCpf(id)) ||
        id.length < 3 ||
        id.length > 14) {
      throw const FiscalValidationException(
        'A identificação do destinatário do QR Code 3.00 é inválida.',
        code: 'INVALID_QR_CODE_RECIPIENT',
      );
    }
    return (type: '$resolvedType', id: id);
  }

  static XmlDocument _parseXml(String value) {
    try {
      return XmlDocument.parse(value);
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'XML NFC-e inválido para injeção do QR Code.',
        code: 'INVALID_NFCE_XML',
        cause: error,
      );
    }
  }

  static XmlElement _find(XmlElement root, String name) {
    if (root.localName == name) return root;
    final optional = _findOptional(root, name);
    if (optional != null) return optional;
    throw FiscalValidationException(
      'Elemento NFC-e obrigatório ausente: $name.',
      code: 'INVALID_NFCE_XML',
    );
  }

  static XmlElement? _findOptional(XmlElement root, String name) {
    if (root.localName == name) return root;
    for (final node in root.descendants) {
      if (node is XmlElement && node.localName == name) return node;
    }
    return null;
  }

  static void _assertBase64Shape(String value) {
    if (value.trim().isEmpty) {
      throw const FiscalValidationException(
        'O DigestValue deve ser Base64 válido.',
        code: 'INVALID_DIGEST_VALUE',
      );
    }
    try {
      base64Decode(value);
    } on FormatException {
      throw const FiscalValidationException(
        'O DigestValue deve ser Base64 válido.',
        code: 'INVALID_DIGEST_VALUE',
      );
    }
  }

  static String _sha1Hex(String value) =>
      crypto.sha1.convert(utf8.encode(value)).toString();

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Dados prontos para inclusão no DANFE NFC-e ou em um gerador de QR Code.
class NfceQrCodePayload {
  const NfceQrCodePayload._({required this.data, required this.baseUrl});

  /// Conteúdo do parâmetro `p`, sem percent-encoding.
  final String data;

  /// Endpoint informado pela UF.
  final String baseUrl;

  /// URL final, preservando os separadores fiscais `|` do payload.
  String get url =>
      '${baseUrl.contains('?') ? '$baseUrl&' : '$baseUrl?'}p=$data';
}
