import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4 ||
      arguments[0] != '--manifest' ||
      arguments[2] != '--directory') {
    stderr.writeln(
      'Uso: dart run tool/verify_schema_manifest.dart '
      '--manifest arquivo.json --directory diretório',
    );
    exitCode = 64;
    return;
  }

  final manifestFile = File(arguments[1]);
  final directory = Directory(arguments[3]);
  if (!manifestFile.existsSync() || !directory.existsSync()) {
    stderr.writeln('Manifesto ou diretório de schemas não encontrado.');
    exitCode = 66;
    return;
  }

  final dynamic decoded = jsonDecode(await manifestFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Manifesto inválido.');
    exitCode = 65;
    return;
  }

  if (decoded['files'] is Map) {
    final files = Map<String, dynamic>.from(decoded['files'] as Map);
    for (final entry in files.entries) {
      final relative = entry.key;
      final expected = entry.value;
      if (expected is! String ||
          relative.isEmpty ||
          relative.contains('..') ||
          relative.contains('/') ||
          relative.contains('\\')) {
        stderr.writeln('Entrada de manifesto inválida: $relative');
        exitCode = 65;
        return;
      }
      final file = File('${directory.path}${Platform.pathSeparator}$relative');
      if (!file.existsSync()) {
        stderr.writeln('Arquivo ausente: ${file.path}');
        exitCode = 66;
        return;
      }
      final actual = sha256.convert(await file.readAsBytes()).toString();
      if (actual != expected) {
        stderr.writeln(
          'Hash divergente em $relative: esperado $expected, obtido $actual',
        );
        exitCode = 65;
        return;
      }
    }
    stdout.writeln('Manifesto verificado: ${files.length} arquivos.');
    return;
  }

  final expectedCount = decoded['file_count'];
  final expectedAggregate = decoded['aggregate_sha256'];
  if (expectedCount is! int || expectedAggregate is! String) {
    stderr.writeln(
      'Manifesto deve conter `files` ou `file_count` + `aggregate_sha256`.',
    );
    exitCode = 65;
    return;
  }

  final files = directory.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.length != expectedCount) {
    stderr.writeln(
      'Quantidade divergente: esperado $expectedCount, obtido ${files.length}.',
    );
    exitCode = 65;
    return;
  }
  final lines = <String>[];
  for (final file in files) {
    final digest = sha256.convert(await file.readAsBytes()).toString();
    lines.add('$digest  ${file.path}\n');
  }
  final aggregate = sha256.convert(utf8.encode(lines.join())).toString();
  if (aggregate != expectedAggregate) {
    stderr.writeln(
      'Hash agregado divergente: esperado $expectedAggregate, obtido $aggregate',
    );
    exitCode = 65;
    return;
  }
  stdout.writeln('Manifesto verificado: ${files.length} arquivos.');
}
