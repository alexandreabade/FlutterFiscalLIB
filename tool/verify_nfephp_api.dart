import 'dart:io';

/// Verifica que a fachada Dart mantém todos os métodos públicos do Make do
/// NFePHP na referência informada.
///
/// Uso:
///
/// ```text
/// dart run tool/verify_nfephp_api.dart \
///   --php-make /tmp/sped-nfe/src/Make.php \
///   --dart-make lib/src/make.dart
/// ```
void main(List<String> arguments) {
  final phpPath = _option(arguments, '--php-make');
  final dartPath = _option(arguments, '--dart-make') ?? 'lib/src/make.dart';
  if (phpPath == null) {
    stderr.writeln('Informe --php-make apontando para src/Make.php.');
    exitCode = 64;
    return;
  }

  final phpSource = File(phpPath).readAsStringSync();
  final dartSource = File(dartPath).readAsStringSync();
  final phpMethods = _matches(
    phpSource,
    RegExp(r'public\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\('),
  )..remove('__construct');
  final dartMethods = _matches(
    dartSource,
    RegExp(
      r'^\s*(?:[A-Za-z_][A-Za-z0-9_<>?, \[\]]*?)\s+([A-Za-z][A-Za-z0-9_]*)\s*\(',
      multiLine: true,
    ),
  );

  final missing = phpMethods.difference(dartMethods).toList()..sort();
  final extras = dartMethods.difference(phpMethods).toList()..sort();
  stdout.writeln('NFePHP Make: ${phpMethods.length} métodos públicos.');
  stdout.writeln('FlutterFiscalLIB Make: ${dartMethods.length} métodos.');
  if (missing.isNotEmpty) {
    stderr.writeln('Métodos NFePHP sem fachada Dart: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }
  if (extras.isNotEmpty) {
    stdout.writeln('Métodos Dart adicionais: ${extras.join(', ')}');
  }
  stdout.writeln('Superfície pública Make compatível com a referência.');
}

Set<String> _matches(String source, RegExp expression) => {
  for (final match in expression.allMatches(source)) match.group(1)!,
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
