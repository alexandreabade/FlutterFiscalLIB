import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

/// Teste opt-in para homologação real, sem endpoints ou credenciais no pacote.
///
/// Execute somente com um endpoint oficial de homologação e um PFX de teste:
///
/// ```text
/// FLUTTER_FISCAL_SEFAZ_HOMOLOGATION=1 \
/// FLUTTER_FISCAL_SEFAZ_ENDPOINT=https://... \
/// FLUTTER_FISCAL_SEFAZ_UF=11 \
/// FLUTTER_FISCAL_SEFAZ_CUF=11 \
/// FLUTTER_FISCAL_SEFAZ_PFX=/caminho/fora-do-repositorio/teste.p12 \
/// FLUTTER_FISCAL_SEFAZ_PASSWORD=... dart test test/sefaz_homologation_test.dart
/// ```
void main() {
  final environment = Platform.environment;
  final enabled = environment['FLUTTER_FISCAL_SEFAZ_HOMOLOGATION'] == '1';

  test(
    'consulta status da SEFAZ em homologação com mTLS A1',
    () async {
      final endpoint = _required(environment, 'FLUTTER_FISCAL_SEFAZ_ENDPOINT');
      final uf = _required(environment, 'FLUTTER_FISCAL_SEFAZ_UF');
      final cUf = _required(environment, 'FLUTTER_FISCAL_SEFAZ_CUF');
      final pfxPath = _required(environment, 'FLUTTER_FISCAL_SEFAZ_PFX');
      final password = _required(environment, 'FLUTTER_FISCAL_SEFAZ_PASSWORD');
      final identity = await PfxIdentity.fromPfxFile(
        path: pfxPath,
        password: password,
      );
      final client = SefazClient.fromConfig(
        SefazClientConfig(
          endpoint: Uri.parse(endpoint),
          uf: uf,
          environment: 2,
          model: 55,
          certificate: identity,
        ),
      );

      final response = await client.sefazStatusServico(
        cUf: cUf,
        environment: 2,
      );

      expect(response.statusCode, inInclusiveRange(200, 299));
      expect(response.body.trim(), isNotEmpty);
    },
    skip: enabled
        ? false
        : 'Homologação real desabilitada; defina FLUTTER_FISCAL_SEFAZ_HOMOLOGATION=1.',
  );
}

String _required(Map<String, String> environment, String name) {
  final value = environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('Variável obrigatória para homologação: $name');
  }
  return value;
}
