import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2026, 1, 1),
    cnpj: '04252011000110',
    model: 65,
    series: 1,
    number: 3,
    tpEmis: 9,
    cNf: '12345680',
  ).value;

  test('enfileira NFC-e de contingência com idempotência pela chave', () async {
    final store = InMemoryFiscalDocumentStore();
    final queue = NfceOfflineQueue(store: store);

    final record = await queue.enqueue(
      accessKey: key,
      model: 65,
      signedXml: '<NFe Id="NFe$key"/>',
    );

    expect(record.state, FiscalDocumentState.pending);
    expect((await store.list()).single.accessKey, key);
    expect(record.xmlSha256, record.calculatedXmlSha256);
    expect(record.hasValidXmlIntegrity, isTrue);
    final repeated = await queue.enqueue(
      accessKey: key,
      model: 65,
      signedXml: '<NFe Id="NFe$key"/>',
    );
    expect(repeated.id, record.id);
    expect((await store.list()), hasLength(1));
    await expectLater(
      queue.enqueue(
        accessKey: key,
        model: 65,
        signedXml: '<NFe Id="NFe$key" diferente="true"/>',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'CONFLICTING_DOCUMENT_ID',
        ),
      ),
    );
  });

  test('detecta alteração do XML persistido pelo digest SHA-256', () async {
    final store = InMemoryFiscalDocumentStore();
    final queue = NfceOfflineQueue(store: store);
    final record = await queue.enqueue(
      accessKey: key,
      model: 65,
      signedXml: '<NFe/>',
    );
    final corrupted = FiscalDocumentRecord(
      id: record.id,
      accessKey: record.accessKey,
      model: record.model,
      xml: '<NFe corrompida="true"/>',
      createdAt: record.createdAt,
      xmlSha256: record.xmlSha256,
    );

    expect(corrupted.hasValidXmlIntegrity, isFalse);
    expect(
      () => corrupted.assertXmlIntegrity(),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'DOCUMENT_INTEGRITY_MISMATCH',
        ),
      ),
    );
    await expectLater(
      store.insert(corrupted),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('preserva idempotência quando o insert perde uma corrida', () async {
    final store = _InsertRaceStore();
    final queue = NfceOfflineQueue(store: store);

    final record = await queue.enqueue(
      accessKey: key,
      model: 65,
      signedXml: '<NFe/>',
    );

    expect(record.accessKey, key);
    expect((await store.list()), hasLength(1));
  });

  test('não reivindica documento cujo XML perdeu integridade', () async {
    final queue = NfceOfflineQueue(store: _TamperingStore());
    await queue.enqueue(accessKey: key, model: 65, signedXml: '<NFe/>');

    await expectLater(
      queue.claimNext(),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'DOCUMENT_INTEGRITY_MISMATCH',
        ),
      ),
    );
  });

  test(
    'decorador verifica integridade em leitura e escrita do backend',
    () async {
      final inner = _TamperingStore();
      final store = IntegrityCheckingFiscalDocumentStore(inner);
      final record = FiscalDocumentRecord(
        id: key,
        accessKey: key,
        model: 65,
        xml: '<NFe/>',
        createdAt: DateTime.utc(2026, 1, 1),
        xmlSha256:
            '2a8e4c5a8c2f1d8f4c0e4e1e2f3d0b0d3b8b0e3e6c3b8d7f4e8f2b9d0c6a1b2c',
      );
      expect(
        () => store.insert(record),
        throwsA(isA<FiscalValidationException>()),
      );

      final valid = FiscalDocumentRecord(
        id: key,
        accessKey: key,
        model: 65,
        xml: '<NFe/>',
        createdAt: DateTime.utc(2026, 1, 1),
        xmlSha256: FiscalDocumentRecord(
          id: 'digest',
          accessKey: key,
          model: 65,
          xml: '<NFe/>',
          createdAt: DateTime.utc(2026, 1, 1),
        ).calculatedXmlSha256,
      );
      await store.insert(valid);
      await expectLater(
        store.find(key),
        throwsA(isA<FiscalValidationException>()),
      );
    },
  );

  test(
    'aplica transições e não reenvia resposta desconhecida automaticamente',
    () async {
      final queue = NfceOfflineQueue(store: InMemoryFiscalDocumentStore());
      await queue.enqueue(accessKey: key, model: 65, signedXml: '<NFe/>');

      final claimed = await queue.claimNext();
      expect(claimed?.state, FiscalDocumentState.transmitting);
      expect(claimed?.attempts, 1);
      final unknown = await queue.markUnknown(key, 'timeout');
      expect(unknown.state, FiscalDocumentState.unknown);
      expect(await queue.claimNext(), isNull);

      await queue.retryUnknown(key);
      expect((await queue.claimNext())?.attempts, 2);
    },
  );

  test('limpa metadados do retorno anterior ao reabrir unknown', () async {
    final store = InMemoryFiscalDocumentStore();
    final queue = NfceOfflineQueue(
      store: store,
      clock: () => DateTime.utc(2026, 1, 1),
    );
    final record = await queue.enqueue(
      accessKey: key,
      model: 65,
      signedXml: '<NFe/>',
    );
    await queue.claimNext();
    await queue.applyResult(
      record.id,
      const SefazResult(
        statusCode: 103,
        reason: 'Lote recebido',
        receipt: '123456789012345',
        protocol: '999999999999999',
      ),
    );
    await queue.retryUnknown(record.id);

    final reopened = await store.find(record.id);
    expect(reopened!.statusCode, isNull);
    expect(reopened.receipt, isNull);
    expect(reopened.protocol, isNull);
  });

  test('falha transitória só volta à fila após o prazo', () async {
    var now = DateTime.utc(2026, 1, 1);
    final queue = NfceOfflineQueue(
      store: InMemoryFiscalDocumentStore(),
      clock: () => now,
    );
    await queue.enqueue(accessKey: key, model: 65, signedXml: '<NFe/>');
    await queue.claimNext();
    await queue.markFailed(
      key,
      'sem conexão',
      retryAfter: const Duration(hours: 1),
    );
    expect(await queue.claimNext(), isNull);
    now = now.add(const Duration(hours: 1));
    expect((await queue.claimNext())?.state, FiscalDocumentState.transmitting);
  });

  test(
    'serializa claims concorrentes e reserva o documento uma única vez',
    () async {
      final queue = NfceOfflineQueue(store: InMemoryFiscalDocumentStore());
      await queue.enqueue(accessKey: key, model: 65, signedXml: '<NFe/>');

      final claims = await Future.wait([queue.claimNext(), queue.claimNext()]);
      expect(claims.whereType<FiscalDocumentRecord>(), hasLength(1));
      expect(claims.where((claim) => claim == null), hasLength(1));
    },
  );

  test('store atômico reivindica documento diretamente', () async {
    final store = InMemoryFiscalDocumentStore();
    await store.insert(
      FiscalDocumentRecord(
        id: key,
        accessKey: key,
        model: 65,
        xml: '<NFe/>',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final claimed = await store.claimNext(now: DateTime.utc(2026, 1, 1));
    expect(claimed?.state, FiscalDocumentState.transmitting);
    expect((await store.find(key))?.attempts, 1);
  });

  test('store atômico serializa reivindicações concorrentes diretas', () async {
    final store = InMemoryFiscalDocumentStore();
    await store.insert(
      FiscalDocumentRecord(
        id: key,
        accessKey: key,
        model: 65,
        xml: '<NFe/>',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final claims = await Future.wait([
      store.claimNext(now: DateTime.utc(2026, 1, 1)),
      store.claimNext(now: DateTime.utc(2026, 1, 1)),
    ]);
    expect(claims.whereType<FiscalDocumentRecord>(), hasLength(1));
    expect(claims.where((claim) => claim == null), hasLength(1));
    expect((await store.find(key))?.attempts, 1);
  });

  test('rejeita modelo 55 e XML vazio na fila NFC-e', () async {
    final queue = NfceOfflineQueue(store: InMemoryFiscalDocumentStore());
    await expectLater(
      queue.enqueue(accessKey: key, model: 55, signedXml: '<NFe/>'),
      throwsA(isA<FiscalValidationException>()),
    );
    await expectLater(
      queue.enqueue(accessKey: key, model: 65, signedXml: ' '),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('marca documento vencido e não o reivindica para transmissão', () async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final store = InMemoryFiscalDocumentStore();
    final queue = NfceOfflineQueue(store: store, clock: () => now);
    final record = await queue.enqueue(
      accessKey: '3' * 44,
      model: 65,
      signedXml: '<NFe/>',
      deadlineAt: now.add(const Duration(minutes: 5)),
    );

    now = now.add(const Duration(minutes: 5));
    expect(await queue.claimNext(), isNull);
    final expired = await store.find(record.id);
    expect(expired!.state, FiscalDocumentState.expired);
    expect(expired.lastError, contains('Prazo'));
  });

  test(
    'recupera tentativa abandonada como unknown após reinício sem reenviar',
    () async {
      final started = DateTime.utc(2026, 1, 1, 12);
      var now = started;
      final store = InMemoryFiscalDocumentStore();
      final queue = NfceOfflineQueue(
        store: store,
        clock: () => now,
        transmissionLease: const Duration(minutes: 5),
      );
      await queue.enqueue(accessKey: '6' * 44, model: 65, signedXml: '<NFe/>');
      final claimed = await queue.claimNext();
      expect(claimed!.transmittingAt, started);

      now = started.add(const Duration(minutes: 5));
      expect(await queue.claimNext(), isNull);
      final recovered = await store.find(claimed.id);
      expect(recovered!.state, FiscalDocumentState.unknown);
      expect(recovered.transmittingAt, isNull);
      expect(recovered.lastError, contains('consulte a SEFAZ'));
    },
  );

  test('rejeita prazo de transmissão anterior à criação', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final queue = NfceOfflineQueue(
      store: InMemoryFiscalDocumentStore(),
      clock: () => now,
    );
    await expectLater(
      queue.enqueue(
        accessKey: '4' * 44,
        model: 65,
        signedXml: '<NFe/>',
        deadlineAt: now,
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_TRANSMISSION_DEADLINE',
        ),
      ),
    );
  });

  test(
    'alocador de numeração reserva números sem colisão concorrente',
    () async {
      final allocator = InMemoryFiscalNumberAllocator();
      final numbers = await Future.wait(
        List.generate(
          20,
          (_) => allocator.reserve(
            cUf: '11',
            issuerCnpj: '04252011000110',
            model: 65,
            series: 1,
          ),
        ),
      );

      expect(numbers.toSet(), hasLength(20));
      expect(numbers, containsAll(List.generate(20, (index) => index + 1)));
    },
  );
}

class _TamperingStore implements FiscalDocumentStore {
  FiscalDocumentRecord? record;

  @override
  Future<void> insert(FiscalDocumentRecord value) async {
    record = FiscalDocumentRecord(
      id: value.id,
      accessKey: value.accessKey,
      model: value.model,
      xml: '<NFe alterada="true"/>',
      createdAt: value.createdAt,
      xmlSha256: value.xmlSha256,
    );
  }

  @override
  Future<FiscalDocumentRecord?> find(String id) async => record;

  @override
  Future<List<FiscalDocumentRecord>> list({
    Set<FiscalDocumentState>? states,
  }) async => [
    if (record != null && (states == null || states.contains(record!.state)))
      record!,
  ];

  @override
  Future<void> update(FiscalDocumentRecord value) async {
    record = value;
  }
}

class _InsertRaceStore extends InMemoryFiscalDocumentStore {
  bool _firstInsert = true;

  @override
  Future<void> insert(FiscalDocumentRecord record) async {
    if (_firstInsert) {
      _firstInsert = false;
      await super.insert(record);
      throw StateError('simulated concurrent duplicate');
    }
    await super.insert(record);
  }
}
