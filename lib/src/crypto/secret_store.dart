import 'dart:typed_data';

import '../exceptions/fiscal_exception.dart';

/// Contrato para armazenar bytes sensíveis usando o mecanismo seguro da
/// aplicação (por exemplo, Keychain, Keystore ou `flutter_secure_storage`).
///
/// O núcleo não escolhe um plugin nativo nem registra o conteúdo dos segredos.
/// Implementações devem proteger também o acesso à senha do PFX e ao material
/// criptográfico persistido.
abstract interface class FiscalSecretStore {
  /// Lê o segredo associado a [key], ou retorna `null` quando ausente.
  Future<Uint8List?> read(String key);

  /// Persiste [value] de forma segura sob [key].
  Future<void> write(String key, Uint8List value);

  /// Remove o segredo associado a [key].
  Future<void> delete(String key);
}

/// Adaptador para plugins Flutter ou cofres nativos fornecidos pela aplicação.
class CallbackFiscalSecretStore implements FiscalSecretStore {
  /// Cria um adaptador com operações implementadas pela aplicação.
  const CallbackFiscalSecretStore({
    required this.onRead,
    required this.onWrite,
    required this.onDelete,
  });

  /// Callback de leitura; o retorno é copiado antes de ser entregue.
  final Future<Uint8List?> Function(String key) onRead;

  /// Callback de escrita; recebe uma cópia defensiva do valor.
  final Future<void> Function(String key, Uint8List value) onWrite;

  /// Callback de remoção.
  final Future<void> Function(String key) onDelete;

  @override
  Future<Uint8List?> read(String key) async {
    _validateKey(key);
    final value = await onRead(key);
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    _validateKey(key);
    if (value.isEmpty) {
      throw const FiscalValidationException(
        'O segredo não pode ser vazio.',
        code: 'EMPTY_SECRET',
      );
    }
    await onWrite(key, Uint8List.fromList(value));
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);
    await onDelete(key);
  }
}

/// Store em memória para testes e protótipos locais.
///
/// Não deve ser usado para produção: os bytes ficam no heap do processo e não
/// recebem proteção do sistema operacional.
class InMemoryFiscalSecretStore implements FiscalSecretStore {
  final Map<String, Uint8List> _values = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async {
    _validateKey(key);
    final value = _values[key];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    _validateKey(key);
    if (value.isEmpty) {
      throw const FiscalValidationException(
        'O segredo não pode ser vazio.',
        code: 'EMPTY_SECRET',
      );
    }
    _values[key] = Uint8List.fromList(value);
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);
    _values.remove(key);
  }
}

void _validateKey(String key) {
  if (key.trim().isEmpty || key.contains('/') || key.contains(r'\')) {
    throw const FiscalValidationException(
      'A chave do segredo é inválida.',
      code: 'INVALID_SECRET_KEY',
    );
  }
}
