import '../crypto/rsa_signature.dart';
import '../crypto/xml_signature_service.dart';
import '../exceptions/fiscal_exception.dart';
import '../models/nfe_document.dart';
import '../models/contingency.dart';
import '../sefaz/sefaz_client.dart';
import '../sefaz/sefaz_response.dart';
import '../xml/nfe_xml_builder.dart';

/// Fachada do fluxo de montagem e assinatura de uma NF-e/NFC-e.
///
/// A classe não transmite nem autoriza o documento. Ela torna explícita a
/// separação entre XML estrutural e XML assinado para evitar que um XML ainda
/// não assinado seja confundido com um documento pronto para a SEFAZ.
class NfeEmissionService {
  /// Cria a fachada com um builder e um assinador opcionais.
  const NfeEmissionService({this.builder = const NfeXmlBuilder(), this.signer});

  /// Builder usado para gerar o XML estrutural.
  final NfeXmlBuilder builder;

  /// Assinador configurado, quando o fluxo inclui assinatura.
  final XmlSignatureService? signer;

  /// Gera apenas o XML estrutural, sem assinatura digital.
  String build(NfeDocument document) => builder.build(document);

  /// Gera e assina o XML com o assinador configurado.
  ///
  /// O caminho de assinatura usa a validação fiscal estrita para evitar que
  /// um XML estruturalmente montável, mas sem identificação mínima exigida,
  /// seja confundido com documento pronto para transmissão.
  Future<String> buildAndSign(NfeDocument document) {
    final signer = this.signer;
    if (signer == null) {
      throw StateError(
        'Configure um XmlSignatureService antes de assinar documentos.',
      );
    }
    return signer.sign(builder.buildStrict(document));
  }

  /// Verifica digest e assinatura RSA de um XML já assinado.
  bool verifySigned(String signedXml, XmlSignatureVerifier verifier) =>
      signer?.verifySignature(signedXml, verifier) ?? false;

  /// Assina e envia o documento ao serviço de autorização configurado.
  ///
  /// Para lote assíncrono, o retorno contém o recibo em [SefazResult.receipt]
  /// e deve ser consultado com `SefazClient.sefazConsultaRecibo()`. O método
  /// não reenvia automaticamente em caso de timeout ou estado desconhecido.
  Future<SefazResult> authorize(
    NfeDocument document, {
    required SefazClient client,
    String lotId = '1',
    int synchronous = 1,
    SefazResponseParser parser = const SefazResponseParser(),
  }) async {
    if (document.contingency?.mode == ContingencyMode.offlineNfce) {
      throw const FiscalValidationException(
        'NFC-e offline deve ser persistida na fila e transmitida posteriormente; '
        'não pode ser autorizada pelo fluxo online.',
        code: 'OFFLINE_DOCUMENT_REQUIRES_QUEUE',
      );
    }
    if (document.model != client.model) {
      throw const FiscalValidationException(
        'O modelo do documento não corresponde ao modelo configurado no cliente SEFAZ.',
        code: 'DOCUMENT_MODEL_MISMATCH',
      );
    }
    return authorizeSigned(
      document,
      await buildAndSign(document),
      client: client,
      lotId: lotId,
      synchronous: synchronous,
      parser: parser,
    );
  }

  /// Autoriza um XML já assinado, permitindo que a aplicação injete o QR Code
  /// da NFC-e entre a assinatura e o envio.
  Future<SefazResult> authorizeSigned(
    NfeDocument document,
    String signedXml, {
    required SefazClient client,
    String lotId = '1',
    int synchronous = 1,
    SefazResponseParser parser = const SefazResponseParser(),
  }) async {
    if (document.contingency?.mode == ContingencyMode.offlineNfce) {
      throw const FiscalValidationException(
        'NFC-e offline deve ser persistida na fila e transmitida posteriormente; '
        'não pode ser autorizada pelo fluxo online.',
        code: 'OFFLINE_DOCUMENT_REQUIRES_QUEUE',
      );
    }
    if (document.model != client.model) {
      throw const FiscalValidationException(
        'O modelo do documento não corresponde ao modelo configurado no cliente SEFAZ.',
        code: 'DOCUMENT_MODEL_MISMATCH',
      );
    }
    final response = await client.sefazEnviaLote(
      lotId,
      signedXml,
      synchronous: synchronous,
    );
    return parser.parse(response.body);
  }

  /// Autoriza uma NF-e/NFC-e assíncrona e consulta o recibo até um estado
  /// terminal ou até [maxReceiptAttempts].
  ///
  /// A consulta nunca reenvia o lote. Se o limite for atingido enquanto o
  /// lote ainda estiver em processamento, o último resultado desconhecido é
  /// devolvido para que a aplicação persista o recibo e continue a consulta
  /// posteriormente.
  Future<SefazResult> authorizeAndAwait(
    NfeDocument document, {
    required SefazClient client,
    String lotId = '1',
    int synchronous = 0,
    int maxReceiptAttempts = 6,
    Duration receiptPollInterval = const Duration(seconds: 2),
    SefazResponseParser parser = const SefazResponseParser(),
  }) async {
    if (synchronous != 0) {
      throw const FiscalValidationException(
        'authorizeAndAwait exige envio assíncrono com synchronous=0.',
        code: 'ASYNC_AUTHORIZATION_REQUIRED',
      );
    }
    if (maxReceiptAttempts <= 0 || receiptPollInterval.isNegative) {
      throw const FiscalValidationException(
        'O limite e o intervalo de consulta do recibo são inválidos.',
        code: 'INVALID_RECEIPT_POLLING_CONFIGURATION',
      );
    }
    var result = await authorize(
      document,
      client: client,
      lotId: lotId,
      synchronous: synchronous,
      parser: parser,
    );
    final receipt = result.receipt;
    if (receipt == null || !result.isReceiptPending) return result;
    for (var attempt = 0; attempt < maxReceiptAttempts; attempt++) {
      if (receiptPollInterval > Duration.zero) {
        await Future<void>.delayed(receiptPollInterval);
      }
      final response = await client.sefazConsultaRecibo(
        receipt,
        environment: document.environment,
      );
      final polled = parser.parse(response.body);
      final accessKey =
          polled.accessKey ?? result.accessKey ?? document.accessKey;
      // O retorno cStat=105 normalmente não repete nRec. Preserve o recibo
      // original para que a aplicação possa persistir o estado e continuar a
      // consulta posteriormente, sem precisar reenviar o lote.
      result = polled.receipt == null
          ? SefazResult(
              statusCode: polled.statusCode,
              reason: polled.reason,
              receipt: receipt,
              accessKey: accessKey,
              protocol: polled.protocol,
              protocols: polled.protocols,
            )
          : polled.accessKey == null
          ? SefazResult(
              statusCode: polled.statusCode,
              reason: polled.reason,
              receipt: polled.receipt,
              accessKey: accessKey,
              protocol: polled.protocol,
              protocols: polled.protocols,
            )
          : polled;
      if (!result.isReceiptPending && !result.isUnknown) return result;
      if (result.isRejected || result.isAuthorized) return result;
    }
    return result;
  }
}
