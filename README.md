# FlutterFiscalLIB

Biblioteca Dart/Flutter para emissão, validação, transmissão e impressão de
documentos fiscais eletrônicos brasileiros.

> Criada e mantida por **Alexandre Abade**.

[![pub.dev](https://img.shields.io/pub/v/flutter_fiscal_lib.svg)](https://pub.dev/packages/flutter_fiscal_lib)
[![Dart](https://img.shields.io/badge/Dart-3.12%2B-0175C2.svg)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-supported-02569B.svg)](https://flutter.dev/)

## Instalação

```bash
flutter pub add flutter_fiscal_lib
```

O pacote atual é `0.1.2`. Para testar a integração completa, use o aplicativo
em `example_flutter/` ou o exemplo Dart em `example/bin/`.

## Status do projeto

O projeto está em desenvolvimento incremental e recebe contribuições por Pull
Request. A versão publicada no pub.dev é adequada para avaliação e integração
controlada; a autorização fiscal em produção depende do certificado, CSC,
credenciamento e regras da UF do usuário.

## Recursos por área

| Área | Recursos |
| --- | --- |
| Documentos | NF-e modelo 55, NFC-e modelo 65, chave de acesso e XML tipado |
| SEFAZ | Catálogo por UF, homologação/produção, SOAP 1.1/1.2, TLS/mTLS e parser de retornos |
| Segurança | Certificado A1, XMLDSig, verificação criptográfica e armazenamento seguro por adaptador |
| NFC-e | QR Code 2.00/3.00, CSC, contingência offline e fila persistível |
| Eventos | Cancelamento, CC-e, manifestação, EPEC, inutilização e eventos complementares |
| DANFE | HTML, PDF A4, PDF térmico 80 mm, texto e ESC/POS |
| Plataformas | Dart, Flutter, Android, iOS, macOS, Linux e Windows |

## Homologação e produção

Comece sempre pelo ambiente de homologação (`environment: 2`). A produção
(`environment: 1`) exige credenciamento fiscal, certificado válido, CSC quando
aplicável e autorização do responsável tributário. Consulte
[`HOMOLOGATION.md`](HOMOLOGATION.md) antes de realizar qualquer chamada real.

A biblioteca não promete autorização fiscal apenas por gerar um XML. O retorno
da SEFAZ deve ser interpretado, persistido e tratado; em caso de timeout ou
falha de rede, consulte o documento antes de reenviar.

## O que a biblioteca oferece

O projeto é desenvolvido incrementalmente, com API pública para modelos de
emitente, destinatário e itens, cálculo de chave, validação estrutural do XML,
tributos de produto e serviço, assinatura A1 XMLDSig de NF-e/eventos,
transporte SOAP/TLS com parser SEFAZ, eventos de cancelamento, CC-e,
manifestação, EPEC e inutilização, contingência offline NFC-e, QR Code 2.00/3.00,
fila persistível, reserva de numeração e renderizadores DANFE textual, HTML e
PDF auxiliares.

O núcleo não armazena certificados, senhas, CSC ou tokens. A aplicação deve
fornecer as credenciais por meio de um armazenamento seguro e configurar o
ambiente de homologação ou produção conscientemente.

## Uso

```dart
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

final document = NfeDocument.fromComponents(
  cUf: '11',
  cnpj: '04252011000110',
  cNf: '12345678',
  number: 1,
  series: 1,
  issueDate: DateTime.now().toUtc(),
  environment: 2,
  model: 55,
  issuer: issuer,
  items: items,
);
final xml = NfeXmlBuilder().build(document);
```

## Cadastro automático da empresa e QR Code NFC-e

Para configurar a UF sem copiar URLs manualmente, use
`FiscalCompanyRegistration`. O catálogo incorporado resolve o cUF, o
autorizador, os endpoints SOAP por operação, as ações SOAP e a URL pública do
QR Code para os modelos 55 e 65, em produção (`1`) ou homologação (`2`):

```dart
final empresa = FiscalCompanyRegistration(
  name: 'Empresa Exemplo LTDA',
  cnpj: '04.252.011/0001-10',
  ie: '123456789',
  uf: 'RO', // sigla da UF: o roteamento é resolvido automaticamente
);

final config = empresa.sefazConfig(model: 65, environment: 2);
final qrCode = empresa.nfceOnlineQrCode(
  accessKey: chaveNfce,
  environment: 2,
  cscId: 1, // usado no QR Code 2.00
  csc: 'CSC_DE_HOMOLOGACAO',
);
print(config.serviceEndpoints);
print(qrCode.url);
```

O exemplo completo, incluindo endereço, cadastro do emitente, chave de acesso,
certificado A1 e criação do cliente SEFAZ, está em
`example/bin/cadastro_empresa_nfce.dart`. O catálogo é derivado do snapshot
dos arquivos de serviços do NFePHP; endpoints estaduais podem mudar, portanto
o snapshot deve ser revisado quando os autorizadores publicarem alterações.
O QR Code online 3.00 não usa CSC; no 2.00 o `idCSC` e o CSC são obrigatórios.

Para o caminho de assinatura e transmissão, use `buildStrict(document)` (ou
`NfeEmissionService`), que exige os campos fiscais mínimos antes do XMLDSig.
`build(document)` permanece disponível para montagem estrutural incremental e
compatibilidade com a fachada `Make`.

O XML gerado não é uma autorização fiscal por si só. A aplicação deve
configurar certificado, endpoint oficial da UF, ambiente e CSC, além de
consultar documentos com resposta desconhecida antes de qualquer reenvio. O
pacote inclui schemas oficiais PL_009_V4, o PL_010f vigente e o PL_010b para
regressão histórica, além de ferramentas XSD externas;
essa validação não é dependência runtime do núcleo Dart. A comunicação real
com SEFAZ e a homologação em dispositivos exigem credenciais e ambientes
externos; o procedimento opt-in está em `HOMOLOGATION.md`. O PDF atual oferece
A4 retrato, A4 paisagem e bobina térmica NFC-e; ainda é um
DANFE auxiliar, não a diagramação fiscal oficial
completa do `sped-da`.

Para validar um XML contra um XSD em desktop ou CI, use
`XsdValidator().validate(schemaPath: ..., xmlPath: ...)`; o adaptador padrão
executa `xmllint`. Em Android/iOS, use
`XsdValidator(contentValidator: ...).validateContent(...)` com um parser XSD
nativo/Flutter; use `assertValidContent(...)` quando quiser a mesma exceção de
falha do caminho `xmllint`. Sem esse adaptador a biblioteca falha explicitamente, pois
esses sistemas não permitem executar processos arbitrários.

Para os schemas oficiais, que referenciam outros XSDs, use
`validateContentBundle(...)`/`assertValidContentBundle(...)` e forneça um mapa
com os recursos nomeados de `xs:include`/`xs:import`.

O exemplo Flutter inclui scaffolds Android, iOS, Linux, macOS e Windows. A
mesma API Dart é usada nos cinco alvos; builds nativos dependem das
ferramentas do respectivo sistema e a instalação em dispositivo físico exige
provisionamento externo.

A matriz detalhada de evidências por plataforma está no arquivo
`PLATFORM_SUPPORT.md` distribuído com o pacote.

O pacote publicado exclui artefatos locais de build, PDFs/PNG de inspeção e o
aplicativo Flutter de demonstração; o código do exemplo continua no
repositório para reprodução e CI.

A justificativa para manter o núcleo fiscal em um único pacote está no arquivo
`ARCHITECTURE.md` distribuído com o pacote.

Quando a UF publicar serviços em URLs diferentes, use
`SefazClientConfig.serviceEndpoints` com `SefazOperation.status`,
`authorization`, `query`, `receipt`, `event` ou `inutilization`. URLs não
informadas reutilizam o endpoint principal; a biblioteca não fornece URLs
inventadas nem desabilita a validação HTTPS.

Quando cada serviço exigir uma ação SOAP diferente, configure
`SefazClientConfig.serviceActions`; a ação específica da operação prevalece
sobre `soapAction` global.

Se o endpoint oficial não enviar uma intermediária da sua cadeia TLS, informe
o certificado CA oficial em `trustedCertificates`. A validação TLS continua
ativa; não use `badCertificateCallback` para ignorar certificados inválidos.

Serviços legados que exigem SOAP 1.1 podem usar
`soapVersion: SefazSoapVersion.soap11`; o padrão é SOAP 1.2.

Para validar uma NF-e assinada antes da consulta SEFAZ, configure um
verificador correspondente à chave pública do certificado. A presença de
`SignatureValue` no XML, sem verificação criptográfica, é rejeitada:

```dart
final verifier = RsaSha1SignatureVerifier(identity.certificate.rsaPublicKey);
final tools = Tools(
  sefaz: client,
  signatureVerifier: (signedXml) =>
      signer.verifySignature(signedXml, verifier),
);
await tools.sefazValidate(xmlAssinado);
```

Para lotes grandes, a compactação compatível com `nfeDadosMsgZip` pode ser
ativada em `Tools.sefazEnviaLote(..., compactar: true)` ou diretamente em
`SefazClient.sefazEnviaLote(..., compress: true)`.

Para NFC-e, o QR Code pode ser calculado com o CSC fornecido pela UF:

```dart
final qr = NfceQrCode.online(
  accessKey: accessKey,
  environment: 2,
  cscId: 1,
  csc: csc,
  baseUrl: 'https://endpoint-da-uf/qrcode',
);
print(qr.url);
```

Quando o XML já tiver sido assinado, o suplemento pode ser inserido sem
alterar `infNFe`:

```dart
final xmlComQrCode = NfceQrCode.injectIntoXml(
  signedXml: xmlAssinado,
  payload: qr,
  keyUrl: 'https://endpoint-da-uf/chave',
);
```

Para gerar um PDF auxiliar A4 ou uma NFC-e térmica de 80 mm:

```dart
final pdf = await DanfePdfRenderer().render(document);
final thermal = await DanfePdfRenderer().render(
  document,
  layout: DanfePdfLayout.nfceThermal80,
);

final thermalCopy = await DanfePdfRenderer().render(
  document,
  layout: DanfePdfLayout.nfceThermal80,
  options: const DanfePdfOptions(
    paperWidthMm: 58,
    establishmentCopy: true,
    offlineDoublePrint: true,
  ),
);
```

Para reproduzir uma saída visual de referência do DANFE A4, use
`dart run tool/render_danfe_example.dart /tmp/danfe.pdf`. O arquivo é um
exemplo de demonstração, não um documento fiscal autorizado.

O DANFE HTML aceita `DanfeHtmlOptions(canceled: true)` para marcar uma via
cancelada na representação auxiliar; essa opção não cancela o documento na
SEFAZ nem altera o XML.

As saídas podem ser entregues a plugins Flutter por
`CallbackFiscalOutputAdapter`, salvas com `FileFiscalOutputAdapter` ou
enviadas diretamente a uma impressora de rede com `TcpFiscalOutputAdapter`.
Para encaminhar um PDF a `printing`, `share_plus` ou a um canal nativo, use
`PdfFiscalOutputAdapter` com o callback do aplicativo.
Para um cupom textual ESC/POS, use `EscPosEncoder().encode(texto)` e envie o
resultado como `FiscalOutputFormat.escPos`; impressoras que exigem outra página
de código podem fornecer `textEncoder` próprio.
Bluetooth e impressão do sistema permanecem adaptadores do aplicativo, sem
dependências nativas obrigatórias no núcleo; para Bluetooth, use
`BluetoothFiscalOutputAdapter` e encaminhe os bytes ao plugin escolhido.

O renderer usa as fontes padrão do pacote `pdf`. Para preservar Unicode
completo, forneça uma fonte TTF/OTF licenciada em
`DanfePdfOptions(fontBytes: fonteBytes)`; o núcleo não distribui fontes.

Identidades A1 também podem ser reexportadas para PKCS#12 sem sair do Dart:
`Certificate.writePfx(certificate: ..., privateKeyInfoDer: ..., password: ...)`.

Para persistência offline, implemente `FiscalDocumentStore` com o banco escolhido pela aplicação. `NfceOfflineQueue` não reenvia automaticamente documentos com resposta desconhecida; a aplicação deve consultar a chave antes de chamar `retryUnknown`.

Para certificados e outros bytes sensíveis, use `FiscalSecretStore` com um
backend seguro da plataforma. `CallbackFiscalSecretStore` permite conectar
Keychain, Keystore ou `flutter_secure_storage` sem acoplar o núcleo a um plugin:

```dart
final secrets = CallbackFiscalSecretStore(
  onRead: (key) => securePlugin.readBytes(key),
  onWrite: (key, value) => securePlugin.writeBytes(key, value),
  onDelete: securePlugin.delete,
);
```

`InMemoryFiscalSecretStore` é somente para testes e protótipos.

Registros criados por `NfceOfflineQueue` também carregam `xmlSha256`, o digest
SHA-256 do XML assinado. Stores concretos devem preservá-lo e chamar
`FiscalDocumentRecord.assertXmlIntegrity()` antes de transmitir, rejeitando
qualquer XML alterado desde a persistência. O exemplo Flutter/Drift inclui a
coluna e a migração correspondente.

## Roadmap

- Expandir a cobertura de homologação opt-in por UF e serviço.
- Ampliar exemplos completos de eventos fiscais e transmissão assíncrona.
- Melhorar a paridade visual do DANFE com os leiautes oficiais.
- Documentar integrações de impressão Bluetooth, TCP e impressão do sistema.
- Manter a compatibilidade pública e a matriz de diferenças em relação ao NFePHP.

## Escopo e rastreabilidade

O port do NFePHP é desenvolvido por módulos, preservando nomes públicos quando
a semântica puder ser mantida. Cada módulo recebe testes, documentação de
diferenças e evidência de validação antes de ser considerado concluído.

## Como contribuir

Contribuições são bem-vindas. Crie uma branch a partir de `main`, implemente a
alteração, adicione ou atualize os testes e abra um Pull Request. Toda mudança
fiscal deve incluir documentação da diferença em relação ao leiaute oficial ou
ao NFePHP quando aplicável.

Antes de enviar uma contribuição, execute:

```bash
dart format .
dart analyze
dart test
```

Nunca envie certificados A1, senhas, CSC, tokens ou arquivos `.env`. Consulte
o [SECURITY.md](SECURITY.md) para reportar vulnerabilidades.

## Agradecimentos

Este projeto é inspirado no ecossistema do [NFePHP](https://github.com/nfephp-org)
e utiliza como referência os leiautes fiscais, manuais técnicos e serviços
oficiais das Secretarias da Fazenda. Consulte [`REFERENCES.md`](REFERENCES.md)
para a rastreabilidade das fontes.

## Autor e licença

Projeto criado por **Alexandre Abade**.

## Contato

- LinkedIn: [Alexandre Abade](https://www.linkedin.com/in/alexandre-abade-92aa9b96/)
- WhatsApp: [55 69 99387-7484](https://wa.me/5569993877484)

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE).

