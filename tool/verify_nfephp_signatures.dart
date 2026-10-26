import 'dart:io';

/// Compara a assinatura textual dos métodos públicos da referência NFePHP
/// com as fachadas Dart e produz um inventário reproduzível.
///
/// A adaptação para Dart não exige a mesma lista de tipos ou a mesma
/// quantidade de argumentos: os parâmetros PHP são frequentemente recebidos
/// como `stdClass` e estado global. O relatório preserva os parâmetros PHP e
/// a declaração Dart encontrada, tornando divergências explícitas em vez de
/// tratá-las como compatibilidade silenciosa.
void main(List<String> arguments) {
  final phpMake = _option(arguments, '--php-make');
  final dartMake = _option(arguments, '--dart-make');
  final phpTools = _option(arguments, '--php-tools');
  final dartTools = _option(arguments, '--dart-tools');
  final reportPath = _option(arguments, '--report');
  if ((phpMake == null) != (dartMake == null) ||
      (phpTools == null) != (dartTools == null) ||
      (phpMake == null && phpTools == null)) {
    stderr.writeln(
      'Informe --php-make/--dart-make e/ou --php-tools/--dart-tools.',
    );
    exitCode = 64;
    return;
  }

  final reports = <String>[];
  if (phpMake != null && dartMake != null) {
    reports.add(_compare('Make', phpMake, dartMake));
  }
  if (phpTools != null && dartTools != null) {
    reports.add(_compare('Tools', phpTools, dartTools));
  }
  final report = reports.join('\n\n');
  stdout.write('$report\n');
  if (reportPath != null) {
    File(
      reportPath,
    ).writeAsStringSync('# Inventário de assinaturas\n\n$report\n');
  }
}

String _compare(String label, String phpPath, String dartPath) {
  final php = _extract(File(phpPath).readAsStringSync(), php: true);
  final dartSource = File(dartPath).readAsStringSync();
  final missing = <String>[];
  final rows = <String>[
    '## $label',
    '',
    '| Método | Parâmetros PHP | Declaração Dart |',
    '| --- | --- | --- |',
  ];
  for (final method in php) {
    final dart = _findDartDeclaration(dartSource, method.name);
    if (dart == null) missing.add(method.name);
    rows.add(
      '| `${method.name}` | `${_inline(method.parameters)}` | '
      '`${_inline(dart ?? 'AUSENTE')}` |',
    );
  }
  stdout.writeln(
    '$label: ${php.length} métodos públicos; ausentes: ${missing.length}.',
  );
  if (missing.isNotEmpty) {
    stderr.writeln('$label sem fachada Dart: ${missing.join(', ')}');
    exitCode = 1;
  }
  return rows.join('\n');
}

List<_Method> _extract(String source, {required bool php}) {
  final pattern = php
      ? RegExp(r'public\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
      : RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(');
  final methods = <_Method>[];
  for (final match in pattern.allMatches(source)) {
    final name = match.group(1)!;
    if (php && name == '__construct') continue;
    final open = source.indexOf('(', match.start);
    final close = _matchingParen(source, open);
    if (close < 0) continue;
    methods.add(_Method(name, source.substring(open + 1, close).trim()));
  }
  return methods;
}

String? _findDartDeclaration(String source, String name) {
  final pattern = RegExp('\\b${RegExp.escape(name)}\\s*\\(');
  for (final match in pattern.allMatches(source)) {
    final open = source.indexOf('(', match.start);
    final close = _matchingParen(source, open);
    if (close >= 0) {
      final prefix = source.substring(
        source.lastIndexOf('\n', match.start) + 1,
        match.start,
      );
      if (prefix.contains('///') || prefix.contains('//')) continue;
      return source.substring(match.start, close + 1).trim();
    }
  }
  return null;
}

int _matchingParen(String source, int open) {
  var depth = 0;
  var quote = 0;
  for (var index = open; index < source.length; index++) {
    final code = source.codeUnitAt(index);
    if (quote != 0) {
      if (code == quote && (index == 0 || source.codeUnitAt(index - 1) != 92)) {
        quote = 0;
      }
      continue;
    }
    if (code == 39 || code == 34) {
      quote = code;
    } else if (code == 40) {
      depth++;
    } else if (code == 41 && --depth == 0) {
      return index;
    }
  }
  return -1;
}

String _inline(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', '\\|');

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length
      ? arguments[index + 1]
      : null;
}

class _Method {
  const _Method(this.name, this.parameters);

  final String name;
  final String parameters;
}
