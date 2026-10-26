import 'dart:io';

/// Compara os marcadores do layout TXT local 4.00 do NFePHP com o mapa Dart.
///
/// O marcador oficial `B19` é aceito também pelo alias histórico `BA19`.
void main(List<String> arguments) {
  final phpPath = _option(arguments, '--php-layout');
  final dartPath =
      _option(arguments, '--dart-validator') ??
      'lib/src/validation/nfe_txt_validator.dart';
  if (phpPath == null) {
    stderr.writeln('Informe --php-layout apontando para txtlayout400.md.');
    exitCode = 64;
    return;
  }

  final phpRecords = _records(File(phpPath).readAsStringSync());
  final dartSource = File(dartPath).readAsStringSync();
  final dartRecords = {
    for (final match in RegExp(
      r'^\s*"([A-Z][A-Z0-9]*)"\s*:',
      multiLine: true,
    ).allMatches(dartSource))
      match.group(1)!,
  };
  final missing = <String>[];
  for (final record in phpRecords) {
    if (record == 'B19' && dartRecords.contains('BA19')) continue;
    if (!dartRecords.contains(record)) missing.add(record);
  }
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Marcadores NFePHP sem estrutura Dart: ${missing.join(', ')}',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Inventário TXT compatível: ${phpRecords.length} marcadores oficiais; '
    '${dartRecords.length} entradas Dart incluindo aliases.',
  );
}

Set<String> _records(String source) => {
  for (final match in RegExp(
    r'^([A-Za-z][A-Za-z0-9]*)\|',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!.toUpperCase(),
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
