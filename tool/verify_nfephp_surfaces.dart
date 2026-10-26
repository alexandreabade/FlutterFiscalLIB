import 'dart:io';

/// Compara superfícies públicas adicionais do NFePHP com as fachadas Dart.
///
/// O comando recebe os três arquivos da referência fixada:
///
/// ```text
/// dart run tool/verify_nfephp_surfaces.dart \
///   --php-complements .ci/nfephp/src/Complements.php \
///   --dart-complements lib/src/complements.dart \
///   --php-standardize .ci/nfephp/src/Common/Standardize.php \
///   --dart-standardize lib/src/standardize.dart \
///   --php-certificate .ci/nfephp/vendor/nfephp-org/sped-common/src/Certificate.php \
///   --dart-certificate lib/src/crypto/certificate.dart
/// ```
void main(List<String> arguments) {
  final pairs = <String, String>{
    'Complements': _required(arguments, '--php-complements'),
    'Standardize': _required(arguments, '--php-standardize'),
    'Certificate': _required(arguments, '--php-certificate'),
  };
  final dartPaths = <String, String>{
    'Complements': _required(arguments, '--dart-complements'),
    'Standardize': _required(arguments, '--dart-standardize'),
    'Certificate': _required(arguments, '--dart-certificate'),
  };

  var failed = false;
  for (final entry in pairs.entries) {
    final phpMethods = _phpMethods(File(entry.value).readAsStringSync());
    final dartMethods = _dartMethods(
      File(dartPaths[entry.key]!).readAsStringSync(),
    );
    final missing = phpMethods.difference(dartMethods).toList()..sort();
    final extras = dartMethods.difference(phpMethods).toList()..sort();
    stdout.writeln(
      '${entry.key}: NFePHP ${phpMethods.length}; '
      'FlutterFiscalLIB ${dartMethods.length}.',
    );
    if (missing.isNotEmpty) {
      stderr.writeln(
        '${entry.key}: métodos sem fachada Dart: ${missing.join(', ')}',
      );
      failed = true;
    }
    if (extras.isNotEmpty) {
      stdout.writeln(
        '${entry.key}: métodos Dart adicionais: ${extras.join(', ')}',
      );
    }
  }
  if (failed) exitCode = 1;
}

Set<String> _phpMethods(String source) => {
  for (final match in RegExp(
    r'public\s+(?:static\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
  ).allMatches(source))
    if (match.group(1) != '__construct')
      match.group(1) == '__toString' ? 'toString' : match.group(1)!,
};

Set<String> _dartMethods(String source) => {
  for (final match in RegExp(
    r'^\s*(?:static\s+)?(?:factory\s+)?'
    r'[A-Za-z_][A-Za-z0-9_<>?, \[\]]*\s+'
    r'([A-Za-z][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!,
};

String _required(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  if (index < 0 || index + 1 >= arguments.length) {
    stderr.writeln('Informe $option e o caminho correspondente.');
    exit(64);
  }
  return arguments[index + 1];
}
