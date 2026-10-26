import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'offline_database.g.dart';

/// Tabela local do exemplo para documentos NFC-e pendentes.
class OfflineDocuments extends Table {
  /// Identificador idempotente.
  TextColumn get id => text()();

  /// Chave de acesso fiscal.
  TextColumn get accessKey => text()();

  /// Modelo fiscal.
  IntColumn get model => integer()();

  /// XML assinado persistido.
  TextColumn get xml => text()();

  /// Digest SHA-256 do XML para detectar corrupção local.
  TextColumn get xmlSha256 => text().nullable()();

  /// Índice de [FiscalDocumentState].
  IntColumn get state => integer()();

  /// Número de tentativas de transmissão.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Data de criação.
  DateTimeColumn get createdAt => dateTime()();

  /// Último erro não secreto.
  TextColumn get lastError => text().nullable()();

  /// Próxima tentativa agendada.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Prazo legal para transmissão do documento.
  DateTimeColumn get deadlineAt => dateTime().nullable()();

  /// Momento da tentativa, usado para recuperar reinícios inesperados.
  DateTimeColumn get transmittingAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sequência fiscal reservada transacionalmente por UF, emitente, modelo e
/// série.
class FiscalNumberSequences extends Table {
  /// UF em dois dígitos.
  TextColumn get cUf => text()();

  /// CNPJ do emitente sem pontuação.
  TextColumn get issuerCnpj => text()();

  /// Modelo 55 ou 65.
  IntColumn get model => integer()();

  /// Série fiscal.
  IntColumn get series => integer()();

  /// Próximo número ainda não reservado.
  IntColumn get nextNumber => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {cUf, issuerCnpj, model, series};
}

/// Banco SQLite/Drift usado pelo exemplo Flutter.
@DriftDatabase(tables: [OfflineDocuments, FiscalNumberSequences])
class ExampleFiscalDatabase extends _$ExampleFiscalDatabase {
  /// Cria o banco a partir de um executor Drift.
  ExampleFiscalDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(fiscalNumberSequences);
      }
      if (from < 3) {
        await m.addColumn(offlineDocuments, offlineDocuments.deadlineAt);
      }
      if (from < 4) {
        await m.addColumn(offlineDocuments, offlineDocuments.xmlSha256);
      }
      if (from < 5) {
        await m.addColumn(offlineDocuments, offlineDocuments.transmittingAt);
      }
    },
  );

  /// Insere um registro fiscal.
  Future<void> insertRecord(FiscalDocumentRecord record) async {
    await into(
      offlineDocuments,
    ).insert(_toCompanion(record), mode: InsertMode.insertOrAbort);
  }

  /// Busca um registro fiscal.
  Future<FiscalDocumentRecord?> findRecord(String id) async {
    final row = await (select(
      offlineDocuments,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Lista registros fiscais por estado.
  Future<List<FiscalDocumentRecord>> listRecords({
    Set<FiscalDocumentState>? states,
  }) async {
    final query = select(offlineDocuments)
      ..where(
        (table) => states == null
            ? const Constant(true)
            : table.state.isIn(states.map((state) => state.index).toList()),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Atualiza um registro fiscal.
  Future<void> updateRecord(FiscalDocumentRecord record) async {
    final changed =
        await (update(offlineDocuments)
              ..where((table) => table.id.equals(record.id)))
            .write(_toCompanion(record, includeId: false));
    if (changed != 1) {
      throw const FiscalValidationException(
        'O documento informado não existe no armazenamento.',
        code: 'DOCUMENT_NOT_FOUND',
      );
    }
  }

  /// Reserva o próximo número da série dentro de uma transação SQLite.
  Future<int> reserveFiscalNumber({
    required String cUf,
    required String issuerCnpj,
    required int model,
    required int series,
  }) => transaction(() async {
    final existing =
        await (select(fiscalNumberSequences)..where(
              (table) =>
                  table.cUf.equals(cUf) &
                  table.issuerCnpj.equals(issuerCnpj) &
                  table.model.equals(model) &
                  table.series.equals(series),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await into(fiscalNumberSequences).insert(
        FiscalNumberSequencesCompanion.insert(
          cUf: cUf,
          issuerCnpj: issuerCnpj,
          model: model,
          series: series,
          nextNumber: const Value(2),
        ),
      );
      return 1;
    }
    final reserved = existing.nextNumber;
    if (reserved > 999999999) {
      throw const FiscalValidationException(
        'A série fiscal esgotou a faixa de numeração disponível.',
        code: 'FISCAL_NUMBER_EXHAUSTED',
      );
    }
    await (update(fiscalNumberSequences)..where(
          (table) =>
              table.cUf.equals(cUf) &
              table.issuerCnpj.equals(issuerCnpj) &
              table.model.equals(model) &
              table.series.equals(series),
        ))
        .write(FiscalNumberSequencesCompanion(nextNumber: Value(reserved + 1)));
    return reserved;
  });

  /// Reivindica o próximo documento elegível dentro de uma transação.
  Future<FiscalDocumentRecord?> claimNextRecord({
    required DateTime now,
  }) => transaction(() async {
    final staleRows =
        await (select(offlineDocuments)..where(
              (table) =>
                  table.state.equals(FiscalDocumentState.transmitting.index),
            ))
            .get();
    for (final row in staleRows) {
      final started = row.transmittingAt;
      if (started == null ||
          started.add(const Duration(minutes: 15)).isAfter(now.toUtc())) {
        continue;
      }
      await (update(
        offlineDocuments,
      )..where((table) => table.id.equals(row.id))).write(
        OfflineDocumentsCompanion(
          state: Value(FiscalDocumentState.unknown.index),
          lastError: Value(
            'A tentativa foi interrompida; consulte a SEFAZ antes de reenviar.',
          ),
          transmittingAt: Value(null),
        ),
      );
    }
    final rows =
        await (select(offlineDocuments)
              ..where(
                (table) => table.state.isIn([
                  FiscalDocumentState.pending.index,
                  FiscalDocumentState.failed.index,
                ]),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    for (final row in rows) {
      final deadline = row.deadlineAt;
      if (deadline != null && !deadline.isAfter(now.toUtc())) {
        await (update(
          offlineDocuments,
        )..where((table) => table.id.equals(row.id))).write(
          OfflineDocumentsCompanion(
            state: Value(FiscalDocumentState.expired.index),
            lastError: const Value('Prazo legal de transmissão expirado.'),
            nextAttemptAt: const Value(null),
          ),
        );
        continue;
      }
      final nextAttempt = row.nextAttemptAt;
      if (nextAttempt != null && nextAttempt.isAfter(now.toUtc())) continue;
      final current = _fromRow(row);
      current.assertXmlIntegrity();
      final claimed = current.copyWith(
        state: FiscalDocumentState.transmitting,
        attempts: current.attempts + 1,
        transmittingAt: now.toUtc(),
        clearLastError: true,
        clearNextAttemptAt: true,
      );
      await (update(offlineDocuments)
            ..where((table) => table.id.equals(row.id)))
          .write(_toCompanion(claimed, includeId: false));
      return claimed;
    }
    return null;
  });

  OfflineDocumentsCompanion _toCompanion(
    FiscalDocumentRecord record, {
    bool includeId = true,
  }) => OfflineDocumentsCompanion(
    id: includeId ? Value(record.id) : const Value.absent(),
    accessKey: Value(record.accessKey),
    model: Value(record.model),
    xml: Value(record.xml),
    xmlSha256: Value(record.xmlSha256),
    state: Value(record.state.index),
    attempts: Value(record.attempts),
    createdAt: Value(record.createdAt),
    lastError: Value(record.lastError),
    nextAttemptAt: Value(record.nextAttemptAt),
    deadlineAt: Value(record.deadlineAt),
    transmittingAt: Value(record.transmittingAt),
  );

  FiscalDocumentRecord _fromRow(OfflineDocument row) => FiscalDocumentRecord(
    id: row.id,
    accessKey: row.accessKey,
    model: row.model,
    xml: row.xml,
    xmlSha256: row.xmlSha256,
    createdAt: row.createdAt,
    state: FiscalDocumentState.values[row.state],
    attempts: row.attempts,
    lastError: row.lastError,
    nextAttemptAt: row.nextAttemptAt,
    deadlineAt: row.deadlineAt,
    transmittingAt: row.transmittingAt,
  );
}

/// Adaptador que expõe o banco Drift ao núcleo fiscal.
class DriftFiscalDocumentStore implements RecoverableFiscalDocumentStore {
  /// Cria um store sobre o banco aberto.
  const DriftFiscalDocumentStore(this.database);

  /// Banco Drift subjacente.
  final ExampleFiscalDatabase database;

  @override
  Future<void> insert(FiscalDocumentRecord record) =>
      database.insertRecord(record);

  @override
  Future<FiscalDocumentRecord?> find(String id) => database.findRecord(id);

  @override
  Future<List<FiscalDocumentRecord>> list({Set<FiscalDocumentState>? states}) =>
      database.listRecords(states: states);

  @override
  Future<void> update(FiscalDocumentRecord record) =>
      database.updateRecord(record);

  @override
  Future<FiscalDocumentRecord?> claimNext({required DateTime now}) =>
      database.claimNextRecord(now: now);

  @override
  Future<void> recoverStaleTransmissions({
    required DateTime now,
    required Duration lease,
  }) async {
    // claimNextRecord performs reconciliation and the subsequent claim in
    // the same SQLite transaction. The queue preflight remains a no-op.
  }
}

/// Implementação persistente de [FiscalNumberAllocator] usando transações
/// SQLite do banco Drift do exemplo.
class DriftFiscalNumberAllocator implements FiscalNumberAllocator {
  /// Cria um alocador sobre o banco aberto.
  const DriftFiscalNumberAllocator(this.database);

  /// Banco Drift subjacente.
  final ExampleFiscalDatabase database;

  @override
  Future<int> reserve({
    required String cUf,
    required String issuerCnpj,
    required int model,
    required int series,
  }) => database.reserveFiscalNumber(
    cUf: cUf,
    issuerCnpj: issuerCnpj,
    model: model,
    series: series,
  );
}

/// Abre o banco persistido no diretório de documentos da aplicação.
Future<ExampleFiscalDatabase> openExampleDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, 'flutter_fiscal_lib.sqlite'));
  return ExampleFiscalDatabase(NativeDatabase.createInBackground(file));
}
