/// Erro base para falhas previsíveis da biblioteca fiscal.
class FiscalException implements Exception {
  /// Cria uma exceção com mensagem e contexto opcional.
  const FiscalException(this.message, {this.code, this.cause});

  /// Mensagem legível para o usuário.
  final String message;

  /// Código estável para tratamento programático.
  final String? code;

  /// Causa original, quando disponível.
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

/// Indica que os dados do documento não atendem uma pré-condição.
class FiscalValidationException extends FiscalException {
  /// Cria uma falha de validação.
  const FiscalValidationException(super.message, {super.code, super.cause});
}
