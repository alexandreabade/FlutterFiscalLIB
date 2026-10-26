import 'dart:io';

/// Verifica os artefatos mínimos exigidos para uma publicação reproduzível.
///
/// O gate é deliberadamente estático: ele não declara homologação SEFAZ nem
/// validação em dispositivo físico. Essas evidências possuem suítes próprias.
void main(List<String> arguments) {
  final root = Directory(_option(arguments, '--root') ?? '.');
  final requiredFiles = <String>[
    'pubspec.yaml',
    'LICENSE',
    'README.md',
    'README_EN.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'API_COMPATIBILITY.md',
    'DANFE_COMPATIBILITY.md',
    'MIGRATION_GUIDE.md',
    'TEST_REPORT.md',
    'HOMOLOGATION.md',
    'REFERENCES.md',
    'REFERENCE_ANALYSIS.md',
    'PLATFORM_SUPPORT.md',
    'ARCHITECTURE.md',
    '.gitignore',
    '.pubignore',
    '.github/workflows/ci.yml',
    'schemas/PL_009_V4.MANIFEST.json',
    'schemas/PL_010b_NT2025_002_v1.30.MANIFEST.json',
    'schemas/PL_010f_v1.04.MANIFEST.json',
    'example_flutter/pubspec.yaml',
    'example_flutter/integration_test/offline_flow_test.dart',
  ];
  final missing = requiredFiles
      .where((path) => !File('${root.path}/$path').existsSync())
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Artefatos obrigatórios ausentes: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }

  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  if (!RegExp(
    r'^name:\s*flutter_fiscal_lib\s*$',
    multiLine: true,
  ).hasMatch(pubspec)) {
    stderr.writeln('O pubspec deve declarar o pacote flutter_fiscal_lib.');
    exitCode = 1;
    return;
  }
  final readme = File('${root.path}/README.md').readAsStringSync();
  final security = File('${root.path}/SECURITY.md').readAsStringSync();
  final homologation = File('${root.path}/HOMOLOGATION.md').readAsStringSync();
  final ci = File('${root.path}/.github/workflows/ci.yml').readAsStringSync();
  final gitignore = File('${root.path}/.gitignore').readAsStringSync();
  final pubignore = File('${root.path}/.pubignore').readAsStringSync();
  final checks = <String, bool>{
    'nome FlutterFiscalLIB': readme.contains('FlutterFiscalLIB'),
    'segurança de segredos':
        security.contains('senha') && security.contains('chave privada'),
    'homologação opt-in': homologation.contains(
      'FLUTTER_FISCAL_SEFAZ_HOMOLOGATION',
    ),
    'teste Dart na CI': ci.contains('dart test'),
    'dry-run pub.dev na CI': ci.contains('dart pub publish --dry-run'),
    'higiene do pacote pub.dev':
        pubignore.contains('tmp/') &&
        pubignore.contains('output/') &&
        pubignore.contains('example_flutter/'),
    'exemplo Flutter rastreável': !RegExp(
      r'^\s*example_flutter/?\s*$',
      multiLine: true,
    ).hasMatch(gitignore),
  };
  final failed = checks.entries.where((entry) => !entry.value).toList();
  if (failed.isNotEmpty) {
    stderr.writeln(
      'Verificações de publicação falharam: '
      '${failed.map((entry) => entry.key).join(', ')}',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Release readiness OK: ${requiredFiles.length} artefatos e '
    '${checks.length} invariantes verificados.',
  );
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
