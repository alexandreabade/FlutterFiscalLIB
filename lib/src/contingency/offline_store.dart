import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../exceptions/fiscal_exception.dart';
import '../sefaz/sefaz_response.dart';

/// Estado persistível de um documento fiscal em uma fila de transmissão.
enum FiscalDocumentState {
  /// Documento criado localmente e ainda não transmitido.
  pending,

  /// Uma tentativa de transmissão está em andamento.
  transmitting,

  /// A autorização foi confirmada.
  authorized,

  /// A SEFAZ rejeitou o documento; requer correção ou decisão da aplicação.
  rejected,

  /// A resposta não permitiu saber se a SEFAZ recebeu o documento.
  unknown,

  /// Falha local ou de transporte que pode ser tentada novamente.
  failed,

  /// O prazo de transmissão configurado para o documento foi ultrapassado.
  expired,
}

/// Registro mínimo que uma implementação de persistência deve armazenar.
///
/// A implementação concreta pode adicionar protocolo, recibo, XML de retorno
/// e metadados próprios. O XML original e a chave são mantidos para permitir
/// reconsulta e evitar reemissão acidental.
class FiscalDocumentRecord {
  /// Cria um registro de transmissão.
  const FiscalDocumentRecord({
    required this.id,
    required this.accessKey,
    required this.model,
    required this.xml,
    required this.createdAt,
    this.xmlSha256,
    this.state = FiscalDocumentState.pending,
    this.attempts = 0,
    this.lastError,
    this.nextAttemptAt,
    this.deadlineAt,
    this.transmittingAt,
    this.statusCode,
    this.receipt,
    this.protocol,
  });

  /// Identificador idempotente do registro.
  final String id;

  /// Chave de acesso do documento.
  final String accessKey;

  /// Modelo fiscal, normalmente 55 ou 65.
  final int model;

  /// XML assinado que será transmitido.
  final String xml;

  /// Digest SHA-256 do XML persistido, usado para detectar corrupção local.
  ///
  /// Registros criados por versões anteriores podem não ter o campo; novas
  /// inserções pela fila sempre o preenchem.
  final String? xmlSha256;

  /// Momento de criação do registro.
  final DateTime createdAt;

  /// Estado atual da transmissão.
  final FiscalDocumentState state;

  /// Quantidade de tentativas de transmissão iniciadas.
  final int attempts;

  /// Último erro local ou de transporte, sem material secreto.
  final String? lastError;

  /// Próximo momento em que uma nova tentativa pode ser iniciada.
  final DateTime? nextAttemptAt;

  /// Prazo operacional para transmissão posterior, quando configurado.
  final DateTime? deadlineAt;

  /// Momento em que a tentativa de transmissão foi reivindicada.
  ///
  /// Permite recuperar um processo encerrado depois do `claimNext` sem
  /// reenviar automaticamente um documento que a SEFAZ talvez já tenha
  /// recebido.
  final DateTime? transmittingAt;

  /// Último `cStat` persistido, quando houve resposta fiscal.
  final int? statusCode;

  /// Recibo de lote retornado pela SEFAZ, quando aplicável.
  final String? receipt;

  /// Protocolo fiscal retornado pela SEFAZ, quando aplicável.
  final String? protocol;

  /// Calcula o digest atual do XML armazenado.
  String get calculatedXmlSha256 => sha256.convert(utf8.encode(xml)).toString();

  /// Indica se o digest persistido corresponde ao XML atual.
  bool get hasValidXmlIntegrity =>
      xmlSha256 == null || xmlSha256 == calculatedXmlSha256;

  /// Rejeita um registro cujo XML foi alterado ou corrompido.
  void assertXmlIntegrity() {
    if (!hasValidXmlIntegrity) {
      throw const FiscalValidationException(
        'O XML persistido não corresponde ao digest de integridade.',
        code: 'DOCUMENT_INTEGRITY_MISMATCH',
      );
    }
  }

  /// Indica que o prazo configurado já foi ultrapassado.
  bool isExpiredAt(DateTime now) =>
      deadlineAt != null && !deadlineAt!.isAfter(now.toUtc());

  /// Indica que uma tentativa abandonada precisa ser reconciliada.
  bool isStaleTransmittingAt(DateTime now, Duration lease) {
    final started = transmittingAt;
    return state == FiscalDocumentState.transmitting &&
        started != null &&
        !started.add(lease).isAfter(now.toUtc());
  }

  /// Cria uma cópia com os campos de estado alterados.
  FiscalDocumentRecord copyWith({
    FiscalDocumentState? state,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    DateTime? deadlineAt,
    DateTime? transmittingAt,
    bool clearTransmittingAt = false,
    int? statusCode,
    bool clearStatusCode = false,
    String? receipt,
    bool clearReceipt = false,
    String? protocol,
    bool clearProtocol = false,
  }) => FiscalDocumentRecord(
    id: id,
    accessKey: accessKey,
    model: model,
    xml: xml,
    createdAt: createdAt,
    xmlSha256: xmlSha256,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
    nextAttemptAt: clearNextAttemptAt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    deadlineAt: deadlineAt ?? this.deadlineAt,
    transmittingAt: clearTransmittingAt
        ? null
        : (transmittingAt ?? this.transmittingAt),
    statusCode: clearStatusCode ? null : (statusCode ?? this.statusCode),
    receipt: clearReceipt ? null : (receipt ?? this.receipt),
    protocol: clearProtocol ? null : (protocol ?? this.protocol),
  );
}

/// Persistência necessária para uma fila fiscal offline-first.
///
/// O núcleo não impõe SQLite, Drift ou outro banco. No Flutter, a aplicação
/// pode implementar esta interface em Drift usando transações atômicas.
abstract interface class FiscalDocumentStore {
  /// Insere um registro; deve rejeitar uma chave/id já existente.
  Future<void> insert(FiscalDocumentRecord record);

  /// Busca um registro pelo identificador idempotente.
  Future<FiscalDocumentRecord?> find(String id);

  /// Lista registros, opcionalmente filtrados por estado.
  Future<List<FiscalDocumentRecord>> list({Set<FiscalDocumentState>? states});

  /// Substitui um registro já existente.
  Future<void> update(FiscalDocumentRecord record);
}

/// Decorador de persistência que aplica a verificação de integridade em
/// qualquer backend fornecido pela aplicação.
///
/// O decorador não tenta simular uma reivindicação atômica: quando o backend
/// também implementa [AtomicFiscalDocumentStore], a aplicação pode manter
/// essa implementação diretamente e validar o registro retornado antes do
/// envio. Para backends comuns, este adaptador protege todas as operações de
/// leitura e escrita expostas por [FiscalDocumentStore].
class IntegrityCheckingFiscalDocumentStore implements FiscalDocumentStore {
  /// Cria um decorador sobre [inner].
  const IntegrityCheckingFiscalDocumentStore(this.inner);

  /// Backend original da aplicação.
  final FiscalDocumentStore inner;

  @override
  Future<void> insert(FiscalDocumentRecord record) {
    record.assertXmlIntegrity();
    return inner.insert(record);
  }

  @override
  Future<FiscalDocumentRecord?> find(String id) async {
    final record = await inner.find(id);
    record?.assertXmlIntegrity();
    return record;
  }

  @override
  Future<List<FiscalDocumentRecord>> list({
    Set<FiscalDocumentState>? states,
  }) async {
    final records = await inner.list(states: states);
    for (final record in records) {
      record.assertXmlIntegrity();
    }
    return records;
  }

  @override
  Future<void> update(FiscalDocumentRecord record) {
    record.assertXmlIntegrity();
    return inner.update(record);
  }
}

/// Extensão opcional para stores que conseguem reivindicar um documento em
/// uma transação atômica, evitando corrida entre múltiplos workers.
abstract interface class AtomicFiscalDocumentStore
    implements FiscalDocumentStore {
  /// Reivindica o próximo documento elegível no instante informado.
  Future<FiscalDocumentRecord?> claimNext({required DateTime now});
}

/// Store que consegue reconciliar tentativas abandonadas atomicamente.
abstract interface class RecoverableFiscalDocumentStore
    implements AtomicFiscalDocumentStore {
  /// Marca como `unknown` as tentativas cujo lease expirou.
  Future<void> recoverStaleTransmissions({
    required DateTime now,
    required Duration lease,
  });
}

/// Store determinístico para testes e pequenas integrações locais.
class InMemoryFiscalDocumentStore implements RecoverableFiscalDocumentStore {
  final Map<String, FiscalDocumentRecord> _records = {};
  Future<void> _claimTail = Future<void>.value();

  @override
  Future<void> insert(FiscalDocumentRecord record) async {
    record.assertXmlIntegrity();
    if (_records.containsKey(record.id)) {
      throw const FiscalValidationException(
        'Já existe um documento com o mesmo identificador.',
        code: 'DUPLICATE_DOCUMENT',
      );
    }
    _records[record.id] = record;
  }

  @override
  Future<FiscalDocumentRecord?> find(String id) async => _records[id];

  @override
  Future<List<FiscalDocumentRecord>> list({
    Set<FiscalDocumentState>? states,
  }) async {
    final result = _records.values
        .where((record) => states == null || states.contains(record.state))
        .toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(result);
  }

  @override
  Future<void> update(FiscalDocumentRecord record) async {
    record.assertXmlIntegrity();
    if (!_records.containsKey(record.id)) {
      throw const FiscalValidationException(
        'O documento informado não existe no armazenamento.',
        code: 'DOCUMENT_NOT_FOUND',
      );
    }
    _records[record.id] = record;
  }

  @override
  Future<FiscalDocumentRecord?> claimNext({required DateTime now}) async {
    // Keep the atomic-store contract even when two independent workers call
    // this method directly, without going through NfceOfflineQueue's mutex.
    final previous = _claimTail;
    final finished = Completer<void>();
    _claimTail = finished.future;
    await previous;
    try {
      final candidates =
          _records.values
              .where(
                (record) =>
                    record.state == FiscalDocumentState.pending ||
                    record.state == FiscalDocumentState.failed,
              )
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final candidate in candidates) {
        candidate.assertXmlIntegrity();
        if (candidate.isExpiredAt(now)) {
          _records[candidate.id] = candidate.copyWith(
            state: FiscalDocumentState.expired,
            lastError: 'Prazo de transmissão offline ultrapassado.',
            clearNextAttemptAt: true,
          );
          continue;
        }
        final next = candidate.nextAttemptAt;
        if (next != null && next.isAfter(now)) continue;
        final claimed = candidate.copyWith(
          state: FiscalDocumentState.transmitting,
          attempts: candidate.attempts + 1,
          transmittingAt: now.toUtc(),
          clearLastError: true,
          clearNextAttemptAt: true,
        );
        _records[candidate.id] = claimed;
        return claimed;
      }
      return null;
    } finally {
      finished.complete();
    }
  }

  @override
  Future<void> recoverStaleTransmissions({
    required DateTime now,
    required Duration lease,
  }) async {
    final previous = _claimTail;
    final finished = Completer<void>();
    _claimTail = finished.future;
    await previous;
    try {
      for (final candidate in _records.values.toList()) {
        candidate.assertXmlIntegrity();
        if (!candidate.isStaleTransmittingAt(now, lease)) continue;
        _records[candidate.id] = candidate.copyWith(
          state: FiscalDocumentState.unknown,
          lastError:
              'A tentativa foi interrompida; consulte a SEFAZ antes de reenviar.',
          clearTransmittingAt: true,
        );
      }
    } finally {
      finished.complete();
    }
  }
}

/// Fila de transmissão com transições explícitas e proteção contra duplicidade.
class NfceOfflineQueue {
  /// Cria uma fila usando um store persistível.
  NfceOfflineQueue({
    required this.store,
    DateTime Function()? clock,
    this.transmissionLease = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now {
    if (transmissionLease <= Duration.zero) {
      throw const FiscalValidationException(
        'O lease de transmissão deve ser positivo.',
        code: 'INVALID_TRANSMISSION_LEASE',
      );
    }
  }

  /// Armazenamento usado pela fila.
  final FiscalDocumentStore store;
  final DateTime Function() _clock;

  /// Tempo máximo de uma tentativa antes de exigir reconciliação explícita.
  final Duration transmissionLease;
  Future<void> _operationTail = Future<void>.value();

  /// Adiciona um XML assinado à fila, usando a chave como idempotência.
  Future<FiscalDocumentRecord> enqueue({
    required String accessKey,
    required int model,
    required String signedXml,
    DateTime? createdAt,
    DateTime? deadlineAt,
  }) => _exclusive(() async {
    if (model != 65) {
      throw const FiscalValidationException(
        'A fila offline desta API é exclusiva para NFC-e modelo 65.',
        code: 'OFFLINE_QUEUE_MODEL_NOT_SUPPORTED',
      );
    }
    if (!RegExp(r'^\d{44}$').hasMatch(accessKey)) {
      throw const FiscalValidationException(
        'A chave de acesso deve conter 44 dígitos.',
        code: 'INVALID_ACCESS_KEY',
      );
    }
    if (signedXml.trim().isEmpty) {
      throw const FiscalValidationException(
        'O XML assinado não pode ser vazio.',
        code: 'EMPTY_SIGNED_XML',
      );
    }
    final created = (createdAt ?? _clock()).toUtc();
    final deadline = deadlineAt?.toUtc();
    if (deadline != null && !deadline.isAfter(created)) {
      throw const FiscalValidationException(
        'O prazo de transmissão deve ser posterior à criação do documento.',
        code: 'INVALID_TRANSMISSION_DEADLINE',
      );
    }
    final record = FiscalDocumentRecord(
      id: accessKey,
      accessKey: accessKey,
      model: model,
      xml: signedXml,
      createdAt: created,
      xmlSha256: sha256.convert(utf8.encode(signedXml)).toString(),
      deadlineAt: deadline,
    );
    final existing = await store.find(accessKey);
    if (existing != null) {
      existing.assertXmlIntegrity();
      if (existing.xmlSha256 == record.xmlSha256 &&
          existing.model == record.model) {
        // Repetir a mesma operação é idempotente; não cria uma segunda
        // pendência nem altera o estado fiscal já persistido.
        return existing;
      }
      throw const FiscalValidationException(
        'A chave de acesso já está associada a outro XML fiscal.',
        code: 'CONFLICTING_DOCUMENT_ID',
      );
    }
    try {
      await store.insert(record);
      return record;
    } catch (_) {
      // Backends transacionais podem rejeitar o insert porque outro worker
      // gravou a mesma chave entre o find acima e esta escrita. Releia para
      // preservar idempotência sem esconder falhas de armazenamento reais.
      final raced = await store.find(accessKey);
      if (raced == null) rethrow;
      raced.assertXmlIntegrity();
      if (raced.xmlSha256 == record.xmlSha256 && raced.model == record.model) {
        return raced;
      }
      throw const FiscalValidationException(
        'A chave de acesso já está associada a outro XML fiscal.',
        code: 'CONFLICTING_DOCUMENT_ID',
      );
    }
  });

  /// Reserva o próximo documento elegível e incrementa a tentativa.
  ///
  /// Documentos em estado `unknown` não são reenviados automaticamente: a
  /// aplicação deve primeiro consultar a chave/protocolo e decidir o próximo
  /// estado, evitando duplicidade fiscal.
  Future<FiscalDocumentRecord?> claimNext() => _exclusive(() async {
    final now = _clock().toUtc();
    if (store case final RecoverableFiscalDocumentStore recoverable) {
      await recoverable.recoverStaleTransmissions(
        now: now,
        lease: transmissionLease,
      );
    } else {
      final transmitting = await store.list(
        states: {FiscalDocumentState.transmitting},
      );
      for (final candidate in transmitting) {
        candidate.assertXmlIntegrity();
        if (!candidate.isStaleTransmittingAt(now, transmissionLease)) continue;
        await store.update(
          candidate.copyWith(
            state: FiscalDocumentState.unknown,
            lastError:
                'A tentativa foi interrompida; consulte a SEFAZ antes de reenviar.',
            clearTransmittingAt: true,
          ),
        );
      }
    }
    if (store case final AtomicFiscalDocumentStore atomicStore) {
      return atomicStore.claimNext(now: now);
    }
    final candidates = await store.list(
      states: {FiscalDocumentState.pending, FiscalDocumentState.failed},
    );
    for (final candidate in candidates) {
      candidate.assertXmlIntegrity();
      if (candidate.isExpiredAt(now)) {
        await store.update(
          candidate.copyWith(
            state: FiscalDocumentState.expired,
            lastError: 'Prazo de transmissão offline ultrapassado.',
            clearNextAttemptAt: true,
          ),
        );
        continue;
      }
      final next = candidate.nextAttemptAt;
      if (next != null && next.isAfter(now)) continue;
      final claimed = candidate.copyWith(
        state: FiscalDocumentState.transmitting,
        attempts: candidate.attempts + 1,
        transmittingAt: now,
        clearLastError: true,
        clearNextAttemptAt: true,
      );
      await store.update(claimed);
      return claimed;
    }
    return null;
  });

  /// Marca uma transmissão como autorizada.
  Future<FiscalDocumentRecord> markAuthorized(String id) =>
      _transition(id, FiscalDocumentState.authorized);

  /// Marca uma transmissão como rejeitada pela SEFAZ.
  Future<FiscalDocumentRecord> markRejected(String id, String reason) =>
      _transition(id, FiscalDocumentState.rejected, error: reason);

  /// Marca a resposta como desconhecida; exige consulta antes de reenviar.
  Future<FiscalDocumentRecord> markUnknown(String id, String reason) =>
      _transition(id, FiscalDocumentState.unknown, error: reason);

  /// Persiste um retorno fiscal para a transmissão atual ou para uma consulta.
  Future<FiscalDocumentRecord> applyResult(
    String id,
    SefazResult result, {
    bool fromQuery = false,
  }) => _exclusive(() async {
    final current = await _get(id);
    if (current.state != FiscalDocumentState.transmitting &&
        !(fromQuery && current.state == FiscalDocumentState.unknown)) {
      throw const FiscalValidationException(
        'O retorno fiscal não pode ser aplicado neste estado.',
        code: 'INVALID_RESULT_STATE',
      );
    }
    final state = result.isAuthorized
        ? FiscalDocumentState.authorized
        : result.isRejected
        ? FiscalDocumentState.rejected
        : FiscalDocumentState.unknown;
    final receipt = result.receipt ?? (fromQuery ? current.receipt : null);
    final protocol = result.protocol ?? (fromQuery ? current.protocol : null);
    final next = current.copyWith(
      state: state,
      lastError:
          state == FiscalDocumentState.unknown ||
              state == FiscalDocumentState.rejected
          ? result.reason
          : null,
      clearLastError: state == FiscalDocumentState.authorized,
      clearNextAttemptAt: true,
      clearTransmittingAt: true,
      statusCode: result.statusCode,
      receipt: receipt,
      clearReceipt: receipt == null,
      protocol: protocol,
      clearProtocol: protocol == null,
    );
    await store.update(next);
    return next;
  });

  /// Marca falha transitória e agenda nova tentativa.
  Future<FiscalDocumentRecord> markFailed(
    String id,
    String reason, {
    Duration retryAfter = const Duration(minutes: 1),
  }) => _transition(
    id,
    FiscalDocumentState.failed,
    error: reason,
    nextAttemptAt: _clock().toUtc().add(retryAfter),
  );

  /// Confirma explicitamente que um documento desconhecido pode ser reenviado.
  Future<FiscalDocumentRecord> retryUnknown(String id) => _exclusive(() async {
    final current = await _get(id);
    if (current.isExpiredAt(_clock())) {
      throw const FiscalValidationException(
        'O documento está fora do prazo de transmissão configurado.',
        code: 'TRANSMISSION_DEADLINE_EXPIRED',
      );
    }
    if (current.state != FiscalDocumentState.unknown) {
      throw const FiscalValidationException(
        'Somente documentos com resposta desconhecida podem ser reabertos.',
        code: 'INVALID_UNKNOWN_RETRY_STATE',
      );
    }
    final next = current.copyWith(
      state: FiscalDocumentState.pending,
      clearLastError: true,
      clearNextAttemptAt: true,
      clearTransmittingAt: true,
      clearStatusCode: true,
      clearReceipt: true,
      clearProtocol: true,
    );
    await store.update(next);
    return next;
  });

  Future<FiscalDocumentRecord> _transition(
    String id,
    FiscalDocumentState state, {
    String? error,
    DateTime? nextAttemptAt,
  }) => _exclusive(() async {
    final current = await _get(id);
    if (current.state != FiscalDocumentState.transmitting) {
      throw const FiscalValidationException(
        'Apenas uma transmissão em andamento pode receber resultado.',
        code: 'INVALID_TRANSMISSION_STATE',
      );
    }
    final next = current.copyWith(
      state: state,
      lastError: error,
      nextAttemptAt: nextAttemptAt,
      clearNextAttemptAt: nextAttemptAt == null,
      clearTransmittingAt: true,
    );
    await store.update(next);
    return next;
  });

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _operationTail;
    final finished = Completer<void>();
    _operationTail = finished.future;
    await previous;
    try {
      return await action();
    } finally {
      finished.complete();
    }
  }

  Future<FiscalDocumentRecord> _get(String id) async {
    final record = await store.find(id);
    if (record == null) {
      throw const FiscalValidationException(
        'O documento informado não existe no armazenamento.',
        code: 'DOCUMENT_NOT_FOUND',
      );
    }
    return record;
  }
}
