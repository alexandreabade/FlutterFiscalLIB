import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_fiscal_lib_flutter_example/main.dart';

void main() {
  testWidgets('renderiza a tela principal do exemplo fiscal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FiscalExampleApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('FlutterFiscalLIB'), findsOneWidget);
    expect(find.text('Gerar e persistir NFC-e offline'), findsOneWidget);
    expect(find.text('Configuração da demonstração'), findsOneWidget);
    expect(find.text('Carregar certificado A1'), findsOneWidget);
    expect(find.text('Visualizar DANFE HTML'), findsOneWidget);
    expect(find.text('Preparar cupom ESC/POS'), findsOneWidget);
    expect(find.text('Preparar PDF DANFE'), findsOneWidget);
    expect(find.text('Transmitir pendentes (opt-in)'), findsOneWidget);
  });
}
