import 'package:flutter/services.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Adaptador XSD do exemplo para Android.
///
/// A implementação nativa usa `javax.xml.validation` por MethodChannel. O
/// núcleo Dart continua independente de Flutter e recebe o adaptador por
/// `XsdValidator(contentValidator: ...)`.
class AndroidXsdContentValidator {
  /// Cria um adaptador que conversa com o canal nativo Android.
  const AndroidXsdContentValidator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/xsd');

  final MethodChannel _channel;

  /// Valida um schema e XML mantidos em memória no Android.
  Future<XsdValidationResult> call({
    required String schema,
    required String xml,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'validate',
      {'schema': schema, 'xml': xml},
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD Android não retornou resultado.',
        code: 'XSD_ANDROID_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }

  /// Valida um schema com os arquivos referenciados por include/import.
  Future<XsdValidationResult> callBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'validateBundle',
      {'schema': schema, 'xml': xml, 'resources': resources},
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD Android não retornou resultado.',
        code: 'XSD_ANDROID_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }
}

/// Adaptador XSD do exemplo para iOS.
///
/// A implementação nativa usa `libxml2` do SDK do iOS por MethodChannel.
/// O núcleo Dart continua independente de Flutter e recebe o adaptador por
/// `XsdValidator(contentValidator: ...)`.
class IosXsdContentValidator {
  /// Cria um adaptador que conversa com o canal nativo iOS.
  const IosXsdContentValidator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/xsd');

  final MethodChannel _channel;

  /// Valida um schema e XML mantidos em memória no iOS.
  Future<XsdValidationResult> call({
    required String schema,
    required String xml,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'validate',
      {'schema': schema, 'xml': xml},
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD iOS não retornou resultado.',
        code: 'XSD_IOS_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }

  /// Valida um schema com os arquivos referenciados por include/import.
  Future<XsdValidationResult> callBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'validateBundle',
      {'schema': schema, 'xml': xml, 'resources': resources},
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD iOS não retornou resultado.',
        code: 'XSD_IOS_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }
}

/// Adaptador XSD do exemplo para macOS.
///
/// Usa `libxml2` fornecido pelo SDK macOS através do mesmo contrato nativo do
/// adaptador iOS, com carregamento externo bloqueado.
class MacosXsdContentValidator {
  /// Cria um adaptador que conversa com o canal nativo macOS.
  const MacosXsdContentValidator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/xsd');

  final MethodChannel _channel;

  /// Valida um schema e XML mantidos em memória no macOS.
  Future<XsdValidationResult> call({
    required String schema,
    required String xml,
  }) async {
    return _invoke('validate', {'schema': schema, 'xml': xml});
  }

  /// Valida um bundle XSD com includes/imports no macOS.
  Future<XsdValidationResult> callBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) async {
    return _invoke('validateBundle', {
      'schema': schema,
      'xml': xml,
      'resources': resources,
    });
  }

  Future<XsdValidationResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD macOS não retornou resultado.',
        code: 'XSD_MACOS_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }
}

/// Adaptador XSD do exemplo para Linux.
///
/// Usa `libxml2` do sistema pelo runner GTK, sem executar processos externos.
class LinuxXsdContentValidator {
  /// Cria um adaptador que conversa com o canal nativo Linux.
  const LinuxXsdContentValidator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/xsd');

  final MethodChannel _channel;

  /// Valida um schema e XML mantidos em memória no Linux.
  Future<XsdValidationResult> call({
    required String schema,
    required String xml,
  }) => _invoke('validate', {'schema': schema, 'xml': xml});

  /// Valida um bundle XSD com includes/imports no Linux.
  Future<XsdValidationResult> callBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) => _invoke('validateBundle', {
    'schema': schema,
    'xml': xml,
    'resources': resources,
  });

  Future<XsdValidationResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD Linux não retornou resultado.',
        code: 'XSD_LINUX_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }
}

/// Adaptador XSD do exemplo para Windows.
///
/// Usa MSXML6 pelo runner Windows, com DTD e resolução de recursos externos
/// desabilitados.
class WindowsXsdContentValidator {
  /// Cria um adaptador que conversa com o canal nativo Windows.
  const WindowsXsdContentValidator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/xsd');

  final MethodChannel _channel;

  /// Valida um schema e XML mantidos em memória no Windows.
  Future<XsdValidationResult> call({
    required String schema,
    required String xml,
  }) => _invoke('validate', {'schema': schema, 'xml': xml});

  /// Valida um bundle XSD com includes/imports no Windows.
  Future<XsdValidationResult> callBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) => _invoke('validateBundle', {
    'schema': schema,
    'xml': xml,
    'resources': resources,
  });

  Future<XsdValidationResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    if (response == null) {
      throw const FiscalException(
        'O adaptador XSD Windows não retornou resultado.',
        code: 'XSD_WINDOWS_EMPTY_RESULT',
      );
    }
    return XsdValidationResult(
      exitCode: (response['exitCode'] as num?)?.toInt() ?? 1,
      stdout: '${response['stdout'] ?? ''}',
      stderr: '${response['stderr'] ?? ''}',
    );
  }
}
