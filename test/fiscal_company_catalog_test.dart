import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  const ufCodes = <String, String>{
    'AC': '12',
    'AL': '27',
    'AP': '16',
    'AM': '13',
    'BA': '29',
    'CE': '23',
    'DF': '53',
    'ES': '32',
    'GO': '52',
    'MA': '21',
    'MT': '51',
    'MS': '50',
    'MG': '31',
    'PA': '15',
    'PB': '25',
    'PR': '41',
    'PE': '26',
    'PI': '22',
    'RJ': '33',
    'RN': '24',
    'RS': '43',
    'RO': '11',
    'RR': '14',
    'SC': '42',
    'SP': '35',
    'SE': '28',
    'TO': '17',
  };

  test('resolve endpoints para todas as UFs, modelos e ambientes', () {
    for (final entry in ufCodes.entries) {
      for (final model in [55, 65]) {
        for (final environment in [1, 2]) {
          final profile = SefazEndpointCatalog.resolve(
            uf: entry.key,
            model: model,
            environment: environment,
          );
          expect(profile.cUf, entry.value);
          expect(profile.services, isNotEmpty);
          if (model == 65) {
            expect(profile.qrCodeUrl.scheme, anyOf('http', 'https'));
          }
        }
      }
    }
  });

  test('cria configuração HTTPS com ações e endpoints por operação', () {
    final config = SefazEndpointCatalog.clientConfig(
      uf: 'RO',
      model: 65,
      environment: 2,
    );

    expect(config.uf, '11');
    expect(config.endpoint.scheme, 'https');
    expect(config.serviceEndpoints[SefazOperation.authorization], isNotNull);
    expect(config.serviceActions[SefazOperation.authorization], isNotEmpty);
    expect(
      config.serviceActions[SefazOperation.status],
      'http://www.portalfiscal.inf.br/nfe/wsdl/NFeStatusServico4',
    );
    expect(config.serviceEndpoints[SefazOperation.event], isNotNull);
  });

  test('cadastro da empresa usa somente a UF para roteamento', () {
    final company = FiscalCompanyRegistration(
      name: 'Empresa Exemplo LTDA',
      cnpj: '04.252.011/0001-10',
      ie: '123456789',
      uf: 'ro',
    );

    expect(company.cUf, '11');
    expect(company.party.state, 'RO');
    expect(company.sefazConfig(model: 55, environment: 2).uf, '11');
  });

  test('gera QR Code NFC-e online conforme versão catalogada', () {
    final company = FiscalCompanyRegistration(
      name: 'Empresa Exemplo LTDA',
      cnpj: '04.252.011/0001-10',
      ie: '123456789',
      uf: 'RO',
    );
    final key = AccessKey.fromComponents(
      cUf: company.cUf,
      issueDate: DateTime.utc(2026, 10, 26),
      cnpj: company.cnpj,
      model: 65,
      series: 1,
      number: 42,
      tpEmis: 1,
      cNf: '12345678',
    );
    final profile = SefazEndpointCatalog.resolve(
      uf: 'RO',
      model: 65,
      environment: 2,
    );
    final qr = company.nfceOnlineQrCode(
      accessKey: key.value,
      environment: 2,
      cscId: profile.service('NfeConsultaQR')!.version.startsWith('3')
          ? null
          : 1,
      csc: profile.service('NfeConsultaQR')!.version.startsWith('3')
          ? null
          : 'CSC-DE-TESTE',
    );

    expect(qr.url, contains('p='));
    expect(qr.url, startsWith(profile.qrCodeUrl.toString()));
    expect(qr.data, startsWith(key.value));
  });
}
