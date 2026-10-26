import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test(
    'executa xmllint por adaptador injetável e preserva argumentos',
    () async {
      final temp = await Directory.systemTemp.createTemp('flutter_fiscal_xsd_');
      addTearDown(() => temp.delete(recursive: true));
      final schema = File('${temp.path}/schema.xsd')
        ..writeAsStringSync('schema');
      final xml = File('${temp.path}/document.xml')
        ..writeAsStringSync('<NFe/>');
      String? executable;
      List<String>? arguments;
      final validator = XsdValidator(
        executable: 'xmllint-test',
        runner: (value, received) async {
          executable = value;
          arguments = received;
          return ProcessResult(1, 0, 'ok', '');
        },
      );

      final result = await validator.validate(
        schemaPath: schema.path,
        xmlPath: xml.path,
      );

      expect(result.isValid, isTrue);
      expect(executable, 'xmllint-test');
      expect(arguments, ['--noout', '--schema', schema.path, xml.path]);
    },
  );

  test('rejeita arquivos ausentes antes de chamar o processo', () async {
    const validator = XsdValidator();
    expect(
      () => validator.validate(
        schemaPath: '/missing/schema.xsd',
        xmlPath: '/missing/doc.xml',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'XSD_SCHEMA_NOT_FOUND',
        ),
      ),
    );
  });

  test('permite adaptador XSD em memória para Flutter/mobile', () async {
    String? receivedSchema;
    String? receivedXml;
    final validator = XsdValidator(
      contentValidator: ({required schema, required xml}) async {
        receivedSchema = schema;
        receivedXml = xml;
        return const XsdValidationResult(
          exitCode: 0,
          stdout: 'valid',
          stderr: '',
        );
      },
    );

    final result = await validator.validateContent(
      schema: '<xs:schema/>',
      xml: '<NFe/>',
    );

    expect(result.isValid, isTrue);
    expect(receivedSchema, '<xs:schema/>');
    expect(receivedXml, '<NFe/>');
  });

  test('não confunde análise XML com validação XSD em memória', () async {
    const validator = XsdValidator();
    expect(
      () => validator.validateContent(schema: '<schema/>', xml: '<NFe/>'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'XSD_CONTENT_VALIDATOR_UNAVAILABLE',
        ),
      ),
    );
  });

  test('assertValidContent propaga rejeição do adaptador XSD', () async {
    const validator = XsdValidator(
      contentValidator: _rejectingContentValidator,
    );

    expect(
      () => validator.assertValidContent(schema: '<xs:schema/>', xml: '<NFe/>'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'XSD_VALIDATION_FAILED',
        ),
      ),
    );
  });

  test('encaminha recursos de include/import ao adaptador em bundle', () async {
    Map<String, String>? receivedResources;
    const validator = XsdValidator(bundleValidator: _acceptingBundleValidator);

    final result = await validator.validateContentBundle(
      schema: '<xs:schema><xs:include schemaLocation="types.xsd"/></xs:schema>',
      xml: '<NFe/>',
      resources: const {'types.xsd': '<xs:schema/>'},
    );

    expect(result.isValid, isTrue);
    receivedResources = _lastBundleResources;
    expect(receivedResources, const {'types.xsd': '<xs:schema/>'});
  });

  test('bundle sem adaptador falha explicitamente', () async {
    const validator = XsdValidator();
    expect(
      () => validator.validateContentBundle(
        schema: '<xs:schema/>',
        xml: '<NFe/>',
        resources: const {'types.xsd': '<xs:schema/>'},
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'XSD_BUNDLE_VALIDATOR_UNAVAILABLE',
        ),
      ),
    );
  });
}

Future<XsdValidationResult> _rejectingContentValidator({
  required String schema,
  required String xml,
}) async => const XsdValidationResult(
  exitCode: 1,
  stdout: '',
  stderr: 'elemento inválido',
);

Map<String, String>? _lastBundleResources;

Future<XsdValidationResult> _acceptingBundleValidator({
  required String schema,
  required String xml,
  required Map<String, String> resources,
}) async {
  _lastBundleResources = resources;
  return const XsdValidationResult(exitCode: 0, stdout: 'valid', stderr: '');
}
