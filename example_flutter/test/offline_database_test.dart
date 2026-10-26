import 'package:drift/native.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fiscal_lib_flutter_example/offline_database.dart';

void main() {
  late ExampleFiscalDatabase database;

  setUp(() {
    database = ExampleFiscalDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('reserva números consecutivos em uma transação SQLite', () async {
    final allocator = DriftFiscalNumberAllocator(database);

    expect(
      await allocator.reserve(
        cUf: '11',
        issuerCnpj: '04252011000110',
        model: 65,
        series: 1,
      ),
      1,
    );
    expect(
      await allocator.reserve(
        cUf: '11',
        issuerCnpj: '04252011000110',
        model: 65,
        series: 1,
      ),
      2,
    );
  });

  test('persiste prazo e expira documento durante claim atômico', () async {
    final now = DateTime.utc(2026, 10, 25, 12);
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: now,
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 9,
      cNf: '12345678',
    );
    final store = DriftFiscalDocumentStore(database);
    await store.insert(
      FiscalDocumentRecord(
        id: key.value,
        accessKey: key.value,
        model: 65,
        xml: '<NFe/>',
        createdAt: now.subtract(const Duration(minutes: 5)),
        deadlineAt: now,
      ),
    );

    expect(await store.claimNext(now: now), isNull);
    expect((await store.find(key.value))?.state, FiscalDocumentState.expired);
  });

  test('reconcilia transmissão abandonada no SQLite sem reenviar', () async {
    final started = DateTime.utc(2026, 10, 25, 12);
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: started,
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 2,
      tpEmis: 9,
      cNf: '12345679',
    );
    final store = DriftFiscalDocumentStore(database);
    await store.insert(
      FiscalDocumentRecord(
        id: key.value,
        accessKey: key.value,
        model: 65,
        xml: '<NFe/>',
        createdAt: started,
        state: FiscalDocumentState.transmitting,
        attempts: 1,
        transmittingAt: started,
      ),
    );

    expect(
      await store.claimNext(now: started.add(const Duration(minutes: 15))),
      isNull,
    );
    final recovered = await store.find(key.value);
    expect(recovered!.state, FiscalDocumentState.unknown);
    expect(recovered.transmittingAt, isNull);
  });
}
