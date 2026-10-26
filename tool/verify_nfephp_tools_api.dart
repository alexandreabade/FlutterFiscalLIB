import 'dart:io';

/// Compara os nomes dos métodos públicos de Tools no NFePHP e no Dart.
void main(List<String> arguments) {
  final phpPath = _option(arguments, '--php-tools');
  final dartPath = _option(arguments, '--dart-tools') ?? 'lib/src/tools.dart';
  if (phpPath == null) {
    stderr.writeln('Informe --php-tools apontando para src/Tools.php.');
    exitCode = 64;
    return;
  }
  final phpMethods = _matches(
    File(phpPath).readAsStringSync(),
    RegExp(r'public\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\('),
  )..remove('__construct');
  final dartMethods = _matches(
    File(dartPath).readAsStringSync(),
    RegExp(
      r'^\s*(?:Future<[^>]+>|[A-Za-z_][A-Za-z0-9_<>?, \[\]]*)\s+'
      r'([A-Za-z][A-Za-z0-9_]*)\s*\(',
      multiLine: true,
    ),
  );
  final missing = phpMethods.difference(dartMethods).toList()..sort();
  final extras = dartMethods.difference(phpMethods).toList()..sort();
  stdout.writeln('NFePHP Tools: ${phpMethods.length} métodos públicos.');
  stdout.writeln('FlutterFiscalLIB Tools: ${dartMethods.length} métodos.');
  if (missing.isNotEmpty) {
    stderr.writeln('Métodos Tools sem fachada Dart: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }
  if (extras.isNotEmpty) {
    stdout.writeln('Métodos Dart adicionais: ${extras.join(', ')}');
  }
  stdout.writeln('Superfície pública Tools compatível com a referência.');
}

Set<String> _matches(String source, RegExp expression) => {
  for (final match in expression.allMatches(source)) match.group(1)!,
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
