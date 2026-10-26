// ignore_for_file: avoid_print

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Exemplo completo do cadastro mínimo e do roteamento automático.
///
/// O único campo necessário para escolher os serviços da SEFAZ é [uf].
/// CNPJ, IE e os demais campos continuam sendo usados no XML fiscal.
void main() {
  final empresa = FiscalCompanyRegistration(
    name: 'Empresa Exemplo LTDA',
    fantasyName: 'Mercado Exemplo',
    cnpj: '04.252.011/0001-10',
    ie: '123456789',
    uf: 'RO',
    address: 'Rua Fiscal',
    addressNumber: '100',
    neighborhood: 'Centro',
    cityCode: '1100015',
    city: 'Alta Floresta D Oeste',
    zipCode: '76954000',
    crt: '1',
    phone: '69999999999',
    email: 'fiscal@empresa.exemplo',
  );

  // A biblioteca resolve cUF, autorizador, URLs e SOAP actions.
  final sefazConfig = empresa.sefazConfig(
    model: 65,
    environment: 2, // 1 = produção; 2 = homologação
  );
  print('cUF: ${empresa.cUf}');
  print('endpoint principal: ${sefazConfig.endpoint}');
  print('endpoints por operação: ${sefazConfig.serviceEndpoints}');
  print('ações SOAP: ${sefazConfig.serviceActions}');

  // O cadastro também pode ser convertido diretamente no emitente do XML.
  final emitente = empresa.party;
  print('emitente: ${emitente.name} / ${emitente.state}');

  final chave = AccessKey.fromComponents(
    cUf: empresa.cUf,
    issueDate: DateTime.utc(2026, 10, 26),
    cnpj: empresa.cnpj,
    model: 65,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345678',
  );

  // Para QR Code 2.00, informe idCSC e CSC. Para QR Code 3.00, a UF usa
  // automaticamente o formato 3.00 e esses dois campos são ignorados.
  final qrCode = empresa.nfceOnlineQrCode(
    accessKey: chave.value,
    environment: 2,
    cscId: 1,
    csc: 'CSC-DE-HOMOLOGACAO',
  );
  print('QR Code NFC-e: ${qrCode.url}');

  // Com um certificado A1 real, carregue a identidade e crie o cliente:
  // final identity = PfxIdentity.fromPfx(bytes: pfxBytes, password: senha);
  // final client = SefazClient.fromConfig(
  //   empresa.sefazConfig(
  //     model: 65,
  //     environment: 2,
  //     certificate: identity,
  //   ),
  // );
  // A emissão usa NfeEmissionService com XML assinado e validado.
}
