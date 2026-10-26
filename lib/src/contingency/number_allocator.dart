import 'dart:async';

import '../exceptions/fiscal_exception.dart';

/// Reserva de numeração fiscal fornecida pela aplicação.
///
/// Implementações de produção devem executar a operação em uma transação
/// persistente ou em um serviço coordenador compartilhado entre caixas. A
/// biblioteca não tenta sincronizar dispositivos sem conectividade.
abstract interface class FiscalNumberAllocator {
  /// Reserva e devolve o próximo número da combinação informada.
  Future<int> reserve({
    required String cUf,
    required String issuerCnpj,
    required int model,
    required int series,
  });
}

/// Alocador determinístico em memória para testes e uso local controlado.
class InMemoryFiscalNumberAllocator implements FiscalNumberAllocator {
  /// Cria um alocador iniciando cada série em [firstNumber].
  InMemoryFiscalNumberAllocator({this.firstNumber = 1}) {
    if (firstNumber < 1 || firstNumber > 999999999) {
      throw const FiscalValidationException(
        'O primeiro número fiscal deve estar entre 1 e 999999999.',
        code: 'INVALID_FIRST_FISCAL_NUMBER',
      );
    }
  }

  /// Primeiro número devolvido para uma série ainda não utilizada.
  final int firstNumber;
  final Map<String, int> _nextBySeries = {};
  Future<void> _tail = Future<void>.value();

  @override
  Future<int> reserve({
    required String cUf,
    required String issuerCnpj,
    required int model,
    required int series,
  }) async {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    await previous;
    try {
      final key = '${cUf.trim()}|${issuerCnpj.trim()}|$model|$series';
      final number = _nextBySeries[key] ?? firstNumber;
      if (number > 999999999) {
        throw const FiscalValidationException(
          'A série fiscal esgotou a faixa de numeração disponível.',
          code: 'FISCAL_NUMBER_EXHAUSTED',
        );
      }
      _nextBySeries[key] = number + 1;
      return number;
    } finally {
      finished.complete();
    }
  }
}
