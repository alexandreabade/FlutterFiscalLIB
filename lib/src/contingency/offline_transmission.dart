import '../exceptions/fiscal_exception.dart';
import '../sefaz/sefaz_response.dart';
import 'offline_store.dart';

/// Coordena a transmissão posterior de documentos NFC-e persistidos.
///
/// O transporte é injetado para que a aplicação escolha o endpoint e o
/// certificado adequados. Uma resposta desconhecida nunca é reenviada
/// automaticamente: deve ser resolvida por consulta explícita.
class NfceOfflineTransmissionService {
  /// Cria o coordenador com uma fila persistível.
  const NfceOfflineTransmissionService({required this.queue});

  /// Fila que mantém o estado fiscal durável.
  final NfceOfflineQueue queue;

  /// Tenta transmitir o próximo documento elegível.
  Future<FiscalDocumentRecord?> transmitNext({
    required Future<SefazResult> Function(FiscalDocumentRecord record) send,
  }) async {
    final claimed = await queue.claimNext();
    if (claimed == null) return null;
    try {
      final result = await send(claimed);
      return await queue.applyResult(claimed.id, result);
    } on FiscalException catch (error) {
      if (error.code == 'SEFAZ_TIMEOUT' ||
          error.code == 'SEFAZ_HTTP_ERROR' ||
          error.code == 'SEFAZ_SOAP_FAULT' ||
          error.code == 'SEFAZ_NETWORK_ERROR') {
        return await queue.markUnknown(claimed.id, error.message);
      }
      return await queue.markFailed(claimed.id, error.message);
    } on Object catch (error) {
      return await queue.markFailed(claimed.id, error.toString());
    }
  }

  /// Aplica o resultado de uma consulta a um documento `unknown`.
  Future<FiscalDocumentRecord> resolveUnknown(String id, SefazResult result) =>
      queue.applyResult(id, result, fromQuery: true);
}
