import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:flutter_fiscal_lib_flutter_example/xsd_platform_validator.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('valida XSD no parser nativo da plataforma', (tester) async {
    final XsdContentValidator contentValidator = Platform.isIOS
        ? const IosXsdContentValidator().call
        : Platform.isMacOS
        ? const MacosXsdContentValidator().call
        : Platform.isLinux
        ? const LinuxXsdContentValidator().call
        : Platform.isWindows
        ? const WindowsXsdContentValidator().call
        : const AndroidXsdContentValidator().call;
    final validator = XsdValidator(contentValidator: contentValidator);
    const schema = '''
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="root" type="xs:string"/>
</xs:schema>
''';

    await validator.assertValidContent(
      schema: schema,
      xml: '<root>válido</root>',
    );
    await expectLater(
      validator.assertValidContent(
        schema: schema,
        xml: '<other>inválido</other>',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'XSD_VALIDATION_FAILED',
        ),
      ),
    );

    final XsdContentBundleValidator bundleValidator = Platform.isIOS
        ? const IosXsdContentValidator().callBundle
        : Platform.isMacOS
        ? const MacosXsdContentValidator().callBundle
        : Platform.isLinux
        ? const LinuxXsdContentValidator().callBundle
        : Platform.isWindows
        ? const WindowsXsdContentValidator().callBundle
        : const AndroidXsdContentValidator().callBundle;
    await XsdValidator(
      bundleValidator: bundleValidator,
    ).assertValidContentBundle(
      schema: '''
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:include schemaLocation="included.xsd"/>
  <xs:element name="root" type="RootType"/>
</xs:schema>
''',
      resources: const {
        'included.xsd': '''
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:complexType name="RootType">
    <xs:sequence><xs:element name="value" type="xs:string"/></xs:sequence>
  </xs:complexType>
</xs:schema>
''',
      },
      xml: '<root><value>bundle</value></root>',
    );
  });
}
