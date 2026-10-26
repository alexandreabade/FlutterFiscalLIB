import 'dart:io';

import 'package:test/test.dart';

final bool _hasXmllint =
    Process.runSync('xmllint', ['--version']).exitCode == 0;
final bool _hasOfficialSchemas =
    Directory('schemas/PL_009_V4').existsSync() &&
    Directory('schemas/PL_010f_v1.04').existsSync();

void main() {
  test(
    'valida fixtures geradas pelos exemplos contra os XSDs oficiais',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'flutter_fiscal_xsd_examples_',
      );
      addTearDown(() => temp.delete(recursive: true));

      const examples = [
        (
          tool: 'validate_reform_example.dart',
          schema: 'schemas/PL_010f_v1.04/nfe_v4.00.xsd',
          name: 'reform.xml',
        ),
        (
          tool: 'validate_signed_example.dart',
          schema: 'schemas/PL_010f_v1.04/nfe_v4.00.xsd',
          name: 'signed.xml',
        ),
        (
          tool: 'validate_offline_example.dart',
          schema: 'schemas/PL_010f_v1.04/nfe_v4.00.xsd',
          name: 'offline.xml',
        ),
        (
          tool: 'validate_epec_example.dart',
          schema: 'schemas/PL_009_V4/eventoEPEC_v1.00.xsd',
          name: 'epec.xml',
        ),
        (
          tool: 'validate_inutilization_example.dart',
          schema: 'schemas/PL_009_V4/inutNFe_v4.00.xsd',
          name: 'inutilization.xml',
        ),
      ];

      for (final example in examples) {
        final output = '${temp.path}${Platform.pathSeparator}${example.name}';
        final generator = await Process.run('dart', [
          'run',
          'tool/${example.tool}',
          '--out',
          output,
        ]);
        expect(
          generator.exitCode,
          0,
          reason: '${example.tool}: ${generator.stderr}',
        );

        final validation = await Process.run('xmllint', [
          '--noout',
          '--schema',
          example.schema,
          output,
        ]);
        expect(
          validation.exitCode,
          0,
          reason: '${example.tool}: ${validation.stderr}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: !_hasXmllint || !_hasOfficialSchemas,
  );
}
