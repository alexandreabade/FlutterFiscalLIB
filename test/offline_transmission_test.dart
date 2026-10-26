import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  Future<NfceOfflineTransmissionService> service() async {
    final queue = NfceOfflineQueue(store: InMemoryFiscalDocumentStore());
    await queue.enqueue(accessKey: '5' * 44, model: 65, signedXml: '<NFe/>');
    return NfceOfflineTransmissionService(queue: queue);
  }

  test('persiste autorização, protocolo e cStat na fila', () async {
    final coordinator = await service();
    final record = await coordinator.transmitNext(
      send: (_) async => const SefazResult(
        statusCode: 100,
        reason: 'Autorizado',
        protocol: '123456789012345',
      ),
    );

    expect(record!.state, FiscalDocumentState.authorized);
    expect(record.statusCode, 100);
    expect(record.protocol, '123456789012345');
  });

  test(
    'persiste o recibo quando o lote assíncrono permanece pendente',
    () async {
      final coordinator = await service();
      final pending = await coordinator.transmitNext(
        send: (_) async => const SefazResult(
          statusCode: 103,
          reason: 'Lote recebido',
          receipt: '123456789012345',
        ),
      );

      expect(pending!.state, FiscalDocumentState.unknown);
      expect(pending.statusCode, 103);
      expect(pending.receipt, '123456789012345');
    },
  );

  test(
    'consulta explícita preserva recibo quando o retorno final não o repete',
    () async {
      final coordinator = await service();
      final pending = await coordinator.transmitNext(
        send: (_) async => const SefazResult(
          statusCode: 103,
          reason: 'Lote recebido',
          receipt: '123456789012345',
        ),
      );

      final authorized = await coordinator.resolveUnknown(
        pending!.id,
        const SefazResult(
          statusCode: 100,
          reason: 'Autorizado em consulta',
          protocol: '999999999999999',
        ),
      );

      expect(authorized.state, FiscalDocumentState.authorized);
      expect(authorized.receipt, '123456789012345');
      expect(authorized.protocol, '999999999999999');
    },
  );

  test(
    'timeout vira unknown e só consulta explícita resolve o estado',
    () async {
      final coordinator = await service();
      final unknown = await coordinator.transmitNext(
        send: (_) => Future.error(
          const FiscalException('timeout', code: 'SEFAZ_TIMEOUT'),
        ),
      );

      expect(unknown!.state, FiscalDocumentState.unknown);
      expect(unknown.lastError, 'timeout');
      expect(
        await coordinator.resolveUnknown(
          '5' * 44,
          const SefazResult(
            statusCode: 100,
            reason: 'Autorizado em consulta',
            protocol: '999999999999999',
          ),
        ),
        predicate<FiscalDocumentRecord>(
          (record) =>
              record.state == FiscalDocumentState.authorized &&
              record.protocol == '999999999999999',
        ),
      );
    },
  );

  test('rejeição fiscal não é tratada como falha transitória', () async {
    final coordinator = await service();
    final rejected = await coordinator.transmitNext(
      send: (_) async =>
          const SefazResult(statusCode: 539, reason: 'Rejeição fiscal'),
    );

    expect(rejected!.state, FiscalDocumentState.rejected);
    expect(rejected.statusCode, 539);
    expect(rejected.lastError, 'Rejeição fiscal');
  });

  test('Fault SOAP mantém o documento em estado desconhecido', () async {
    final coordinator = await service();
    final unknown = await coordinator.transmitNext(
      send: (_) => Future.error(
        const FiscalException('falha SOAP', code: 'SEFAZ_SOAP_FAULT'),
      ),
    );

    expect(unknown!.state, FiscalDocumentState.unknown);
    expect(unknown.lastError, 'falha SOAP');
  });

  test('falha de rede mantém o documento em estado desconhecido', () async {
    final coordinator = await service();
    final unknown = await coordinator.transmitNext(
      send: (_) => Future.error(
        const FiscalException('falha DNS', code: 'SEFAZ_NETWORK_ERROR'),
      ),
    );

    expect(unknown!.state, FiscalDocumentState.unknown);
    expect(unknown.lastError, 'falha DNS');
  });
}
