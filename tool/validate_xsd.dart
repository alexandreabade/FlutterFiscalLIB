import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4 ||
      arguments[0] != '--schema' ||
      arguments[2] != '--xml') {
    stderr.writeln(
      'Uso: dart run tool/validate_xsd.dart --schema arquivo.xsd --xml arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final schema = arguments[1];
  final xml = arguments[3];
  try {
    final result = await const XsdValidator().validate(
      schemaPath: schema,
      xmlPath: xml,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } on FiscalException catch (error) {
    stderr.writeln(error.message);
    exitCode = 66;
  }
}
