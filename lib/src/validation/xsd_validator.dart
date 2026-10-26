import 'dart:io';

import '../exceptions/fiscal_exception.dart';

/// Resultado da validação XSD executada por um validador externo.
class XsdValidationResult {
  /// Cria um resultado com código de saída e saídas do processo.
  const XsdValidationResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Código de saída do processo de validação.
  final int exitCode;

  /// Saída padrão do processo.
  final String stdout;

  /// Saída de erro do processo.
  final String stderr;

  /// Indica que o XML passou pelo schema.
  bool get isValid => exitCode == 0;
}

/// Executor injetável para testar a integração com o validador externo.
typedef XsdProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Adaptador para validadores XSD nativos que trabalham em memória.
///
/// Aplicações Flutter podem ligar aqui um parser XSD nativo ou um serviço
/// local sem criar arquivos temporários e sem iniciar processos arbitrários.
typedef XsdContentValidator =
    Future<XsdValidationResult> Function({
      required String schema,
      required String xml,
    });

/// Executor de XSD em memória com recursos para `xs:include`/`xs:import`.
typedef XsdContentBundleValidator =
    Future<XsdValidationResult> Function({
      required String schema,
      required String xml,
      required Map<String, String> resources,
    });

/// Validador XSD baseado em `xmllint` ou executável compatível.
///
/// O núcleo fiscal continua sem depender de XSD em runtime. Esta classe é
/// adequada para desktop, CI e ferramentas de validação. Android/iOS não
/// permitem executar processos arbitrários; nesses alvos, use um validador
/// nativo/aplicativo ou injete um [XsdProcessRunner] compatível.
class XsdValidator {
  /// Cria um validador usando `xmllint` por padrão.
  const XsdValidator({
    this.executable = 'xmllint',
    this.runner,
    this.contentValidator,
    this.bundleValidator,
  });

  /// Nome ou caminho do executável compatível com `xmllint`.
  final String executable;

  /// Executor alternativo, útil para testes e adaptadores nativos.
  final XsdProcessRunner? runner;

  /// Validador em memória para Android/iOS ou adaptadores Flutter nativos.
  final XsdContentValidator? contentValidator;

  /// Validador em memória que resolve os schemas referenciados pelo principal.
  final XsdContentBundleValidator? bundleValidator;

  /// Valida XML e schema fornecidos em memória através de um adaptador.
  ///
  /// O núcleo não inclui um parser XSD Dart incompleto. Quando nenhum
  /// adaptador é configurado, a falha é explícita para evitar que uma simples
  /// análise XML seja confundida com validação fiscal por schema.
  Future<XsdValidationResult> validateContent({
    required String schema,
    required String xml,
  }) async {
    if (schema.trim().isEmpty) {
      throw const FiscalValidationException(
        'O schema XSD em memória não pode ser vazio.',
        code: 'XSD_SCHEMA_EMPTY',
      );
    }
    if (xml.trim().isEmpty) {
      throw const FiscalValidationException(
        'O XML em memória não pode ser vazio.',
        code: 'XSD_XML_EMPTY',
      );
    }
    final validator = contentValidator;
    if (validator == null) {
      throw const FiscalValidationException(
        'Nenhum adaptador XSD em memória foi configurado.',
        code: 'XSD_CONTENT_VALIDATOR_UNAVAILABLE',
      );
    }
    return validator(schema: schema, xml: xml);
  }

  /// Valida conteúdo XSD em memória e lança quando o adaptador rejeita o XML.
  ///
  /// Este é o equivalente multiplataforma de [assertValid] para adaptadores
  /// nativos ou Dart fornecidos pela aplicação, especialmente em Flutter.
  Future<void> assertValidContent({
    required String schema,
    required String xml,
  }) async {
    final result = await validateContent(schema: schema, xml: xml);
    if (!result.isValid) {
      throw FiscalValidationException(
        'O XML não passou no XSD: ${result.stderr.trim().isEmpty ? result.stdout.trim() : result.stderr.trim()}',
        code: 'XSD_VALIDATION_FAILED',
      );
    }
  }

  /// Valida XML contra um schema principal e seus recursos referenciados.
  ///
  /// As chaves de [resources] devem corresponder aos `schemaLocation` usados
  /// no schema, normalmente apenas o nome do arquivo. O adaptador é
  /// responsável por resolver esses nomes sem acessar a rede.
  Future<XsdValidationResult> validateContentBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) async {
    if (schema.trim().isEmpty) {
      throw const FiscalValidationException(
        'O schema XSD em memória não pode ser vazio.',
        code: 'XSD_SCHEMA_EMPTY',
      );
    }
    if (xml.trim().isEmpty) {
      throw const FiscalValidationException(
        'O XML em memória não pode ser vazio.',
        code: 'XSD_XML_EMPTY',
      );
    }
    final validator = bundleValidator;
    if (validator == null) {
      if (resources.isEmpty && contentValidator != null) {
        return contentValidator!(schema: schema, xml: xml);
      }
      throw const FiscalValidationException(
        'Nenhum adaptador XSD em bundle foi configurado.',
        code: 'XSD_BUNDLE_VALIDATOR_UNAVAILABLE',
      );
    }
    return validator(schema: schema, xml: xml, resources: resources);
  }

  /// Valida um bundle XSD e lança quando o adaptador rejeita o XML.
  Future<void> assertValidContentBundle({
    required String schema,
    required String xml,
    required Map<String, String> resources,
  }) async {
    final result = await validateContentBundle(
      schema: schema,
      xml: xml,
      resources: resources,
    );
    if (!result.isValid) {
      throw FiscalValidationException(
        'O XML não passou no XSD: ${result.stderr.trim().isEmpty ? result.stdout.trim() : result.stderr.trim()}',
        code: 'XSD_VALIDATION_FAILED',
      );
    }
  }

  /// Valida [xmlPath] contra [schemaPath].
  Future<XsdValidationResult> validate({
    required String schemaPath,
    required String xmlPath,
  }) async {
    if (!File(schemaPath).existsSync()) {
      throw FiscalValidationException(
        'Schema XSD não encontrado: $schemaPath.',
        code: 'XSD_SCHEMA_NOT_FOUND',
      );
    }
    if (!File(xmlPath).existsSync()) {
      throw FiscalValidationException(
        'XML não encontrado: $xmlPath.',
        code: 'XSD_XML_NOT_FOUND',
      );
    }
    if (runner == null && (Platform.isAndroid || Platform.isIOS)) {
      throw const FiscalValidationException(
        'A execução de xmllint não é suportada diretamente em Android/iOS.',
        code: 'XSD_PROCESS_UNSUPPORTED',
      );
    }
    final process = await (runner ?? Process.run)(executable, [
      '--noout',
      '--schema',
      schemaPath,
      xmlPath,
    ]);
    return XsdValidationResult(
      exitCode: process.exitCode,
      stdout: '${process.stdout}',
      stderr: '${process.stderr}',
    );
  }

  /// Valida e lança quando o processo externo rejeita o XML.
  Future<void> assertValid({
    required String schemaPath,
    required String xmlPath,
  }) async {
    final result = await validate(schemaPath: schemaPath, xmlPath: xmlPath);
    if (!result.isValid) {
      throw FiscalValidationException(
        'O XML não passou no XSD: ${result.stderr.trim().isEmpty ? result.stdout.trim() : result.stderr.trim()}',
        code: 'XSD_VALIDATION_FAILED',
      );
    }
  }
}
