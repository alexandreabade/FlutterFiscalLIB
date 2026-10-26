# Relatório de testes

## Auditoria reproduzível mais recente

Em 26/10/2026, os verificadores foram executados contra o checkout do
`sped-nfe` v5.0.100 (`cf0baf005691c3a9e252314150c7dac18adbb2ee`) com Composer:
`Make` (77 métodos operacionais) e `Tools` (20 métodos) não apresentaram
ausências; a comparação estrutural de `infNFe`, `ide`, `emit`, `dest`, `prod` e
`imposto`, as superfícies `Complements`/`Standardize`/`Certificate` e os 123
marcadores do layout TXT também passaram. O exemplo Flutter foi regenerado com
`dart run build_runner build` sem opções obsoletas, e o teste XSD nativo macOS
passou com 1 caso de integração.

O renderer PDF também cobre o separador vertical tracejado dos itens, ativado
por padrão como no `sped-da` e exercitado junto da opção de linhas contínuas.
O cabeçalho da saída multipágina também exibe `FOLHA 1` e `FOLHA 2` na
continuação; a extração de texto do PDF confirmou os rótulos e o rodapé
`Página 1 de 2`/`Página 2 de 2`.

A matriz do DANFE também cobre `showItemTraceability`, que permite controlar
separadamente as informações de lote, fabricação e validade na descrição dos
itens, com o teste de apresentação térmica exercitando a opção.
O renderer HTML possui os mesmos controles para `infAdProd` e rastreabilidade,
com teste que confirma a ocultação sem alterar o documento fiscal.
O mesmo teste confirma que dados de medicação também desaparecem quando o
bloco adicional é desativado.

O smoke test `test/public_api_surface_test.dart` importa somente o entrypoint
`flutter_fiscal_lib.dart` e referencia 30 tipos públicos das superfícies de
modelo, XML, tributos, assinatura, SEFAZ, contingência, DANFE, validação,
compatibilidade e saída fiscal.

O carregamento A1 também foi testado com dois PFX sintéticos independentes:
quando o certificado de um contêiner é combinado com a chave privada do outro,
`PfxIdentity` rejeita o material com `CERTIFICATE_PRIVATE_KEY_MISMATCH` antes
de disponibilizá-lo para assinatura ou mTLS.

O adaptador XSD Windows foi endurecido para bloquear DTD/entidades externas
também durante o carregamento do schema, rejeitar schema inválido e reportar
falhas de escrita temporária. A compilação/runtime Windows continua sendo
validada pelo job nativo da CI, não por este host macOS.

## Autorização assíncrona com recibo

`NfeEmissionService.authorizeAndAwait()` foi exercitado com lote assíncrono
(`indSinc=0`). O teste confirma que o lote é enviado uma única vez, que a
consulta usa `consReciNFe` com o recibo retornado e que o protocolo autorizado é
normalizado no resultado final. O limite de consultas e o retorno do último
estado desconhecido permitem persistir o recibo quando a SEFAZ ainda estiver
processando o lote. Um segundo cenário mantém `cStat=105` em todas as
consultas, confirma o estado `isReceiptPending` e verifica que, mesmo após o
limite, houve somente um envio do lote, duas consultas do recibo e o `nRec`
original permaneceu disponível para a próxima consulta.
A mesma regressão confirma que a chave original permanece no resultado mesmo
quando a SEFAZ não repete `chNFe` no retorno do recibo.

A fila NFC-e também foi exercitada com retorno `cStat=103`; o registro fica em
`unknown`, preserva `cStat` e `nRec`, e pode ser resolvido por consulta explícita
sem criar uma nova pendência. O teste de resolução final confirma que o
`nRec` continua persistido mesmo quando o retorno autorizado traz somente o
protocolo.

## Representação DANFE para RTC

Os renderizadores PDF e HTML também foram exercitados com os identificadores
fiscais complementares de participantes: IEST, IM, CNAE e SUFRAMA do emitente,
além do indicador de inscrição estadual do destinatário. Esses campos são
apresentados somente quando existem no modelo e não são inferidos.

O DANFE PDF A4 foi reordenado conforme o modelo visual da NT 2026.010:
fatura/duplicatas antes dos totais, bloco `Total do IBS/CBS/IS` após os
totais gerais, ISSQN e transporte antes da tabela de produtos/serviços. A
suíte direcionada de renderização passou com 30 testes; a saída continua
classificada como representação auxiliar até a reprodução completa da
geometria oficial do `sped-da`. O cabeçalho também apresenta IE, IEST,
CNPJ/CPF e CRT, mantendo o tipo futuro de regime IBS/CBS como campo reservado.
Quando há tributação RTC, o PDF também gera quadro por item com classificação,
base, alíquotas, valores IBS/CBS, imposto seletivo e monofasia/retenção.
O renderer HTML foi alinhado à mesma ordem, com transporte e pagamentos em
quadros separados; os testes direcionados PDF/HTML passaram (30 testes).
O teste HTML de reforma também verifica o novo quadro por item e suas
alíquotas formatadas.
Uma renderização A4 atual foi convertida em PNG para inspeção visual: o
cabeçalho, canhoto, quadros fiscais, transporte, produtos e cabeçalho de
continuação ficaram legíveis e sem sobreposição; a página adicional contém as
informações complementares conforme o fluxo multipágina.

O exemplo Flutter também foi revalidado localmente com Flutter 3.47.1/Dart
3.13.1: build_runner gerou 22 saídas, `flutter analyze` não apontou problemas,
os 8 testes Flutter passaram e `flutter build macos --debug` gerou o aplicativo
macOS de debug.
O teste de integração `xsd_platform_test.dart -d macos` também passou com o
parser nativo e o bundle XSD em runtime.

O builder XML valida os totalizadores de ICMS desonerado, diferimento e
devolução do IBS/CBS e créditos presumidos a partir dos valores dos itens.
Isso evita regressões para os zeros fixos anteriormente emitidos em
`ICMSTot/vICMSDeson` e nos grupos correspondentes de `IBSCBSTot`.

O cenário de reforma também confirma a sequência `TIBSCBSMonoTot` usada pelo
leiaute NF-e PL_010f, incluindo os campos obrigatórios de crédito presumido.
O mesmo cenário valida `gEstornoCred` no item e os totais `vIBSEstCred` e
`vCBSEstCred`.
Também valida `gCredPresOper`, seus grupos IBS/CBS e os totais `vCredPres`,
separados do crédito presumido legado de produto.
O fixture RTC também cobre `gCredPresIBSZFM` com competência `2026-01` e passa
na validação do XSD PL_010f.
O cenário de tributação regular também valida a emissão de `indDoacao=1`.
O mesmo cenário valida `gTribRegular` e seus oito campos na sequência oficial
do grupo `gIBSCBS`.
O mesmo cenário valida `gTribCompraGov` e seus seis campos de IBS/CBS.
Os renderizadores DANFE PDF e HTML também preservam esses grupos condicionais
no detalhe fiscal do item e exibem créditos presumidos e estornos no quadro de
totais RTC.
O fixture principal de produtos também valida `nFCI` na ordem oficial de
`prod`, incluindo a rejeição de GUID em formato inválido.
O teste de emissão do `ide` também valida `tpNFDebito` e `tpNFCredito` com os
códigos oficiais do PL_010f.
O teste de produto valida também `indBemMovelUsado`, `infProdNFF` e `infProdEmb`,
incluindo a rejeição dos limites inválidos.
O fixture `validate_reform_example.dart` também inclui esses grupos e é validado
contra o XSD oficial PL_010f pela integração de exemplos.
O cenário ICMS51 também valida o grupo de FCP diferido e sua ordem no XML.
O cenário de variantes do ICMS valida `indDeduzDeson` junto ao grupo de
desoneração.
Há também um cenário específico de `ICMS70`, com validação dos grupos de
redução e desoneração própria/ST.
O `ICMS90` também possui cenário de desoneração própria e de ICMS-ST.
O cenário ICMS60 valida ICMS substituto, FCP-ST retido e valores efetivos,
inclusive no fixture XSD usado pelo CI.
O fixture de variantes ICMS usado no CI também inclui `ICMS70` e é validado
contra o XSD PL_010f com `xmllint`.

O quadro de totais HTML foi alinhado ao PDF para exibir também base e valor
de ICMS, base e valor de ICMS-ST, seguro, II e outras despesas acessórias.
O cenário de renderização HTML valida seguro, II e outros valores informados
no item.

O mesmo cenário valida a exibição de GTIN/EAN e de pedido de compra na tabela
de itens quando a opção correspondente está habilitada.

O teste do builder XML também valida `ICMSTot/vFCPSTRet` com valor retido
informado, evitando regressão para o valor fixo zero.

Os renderizadores PDF e HTML exibem o CRT do emitente e as classificações
`cClassTrib` de IBS/CBS, IBS/CBS monofásico e IS por item sempre que informadas.
`showItemTaxDetails` continua controlando apenas tributos aproximados e benefício
fiscal. Os testes direcionados de DANFE e a
suíte completa (353 aprovados e 1 ignorado) passaram após essa alteração.

O quadro de itens também exibe base, alíquotas e valores calculados de IBS/CBS
e IS, com alíquota efetiva para reduções; os totais PDF/HTML incluem IBS/CBS
monofásicos retidos quando informados. Os testes direcionados de DANFE passaram
após essa ampliação.

O PDF e o HTML também apresentam o quadro separado `Total do IBS/CBS/IS`, com
CBS, IBS UF, IBS município, IS, IBS/CBS monofásicos e respectivas retenções.
Os totais gerais também exibem ICMS monofásico próprio e retido quando
informados.

O teste de geração A4 também cobre `DanfePdfLayout.a4Landscape`; a tabela usa
larguras flexíveis para ocupar a área útil adicional do leiaute paisagem.

Foi adicionado cenário HTML com FCP próprio e FCP-ST, validando a presença dos
dois valores nos totais, além do FCP-ST retido.

## Unidade, quantidade e preço tributáveis no DANFE

Os renderizadores PDF e HTML passaram a exibir `qTrib`, `uTrib` e `vUnTrib`
quando presentes no item, com a opção `showTaxableUnit: false` para a via
resumida. `dart analyze`, os testes direcionados de DANFE, a suíte completa
(353 aprovados e 1 ignorado), `dart doc --validate-links`,
`dart pub publish --dry-run`, `flutter analyze` e `flutter test` do exemplo
foram executados após a alteração.

A opção `generateAutomaticInfo` também foi validada com nota de empenho,
pedido e valor aproximado dos tributos, permanecendo desativada por padrão.
As referências NF legadas, produtor rural e ECF também possuem texto
automático específico quando essa opção é ativada.

## Recuperação após reinício

A fila NFC-e agora persiste o início de cada tentativa de transmissão. O teste
de falha simulada confirma que um lease expirado é convertido para `unknown`,
sem reenvio automático, preservando a necessidade de consulta explícita à
SEFAZ. O banco Drift do exemplo foi migrado para o schema 5 e o exemplo foi
validado com `dart run build_runner build`, `flutter analyze` e `flutter test`
(9 testes aprovados, incluindo o cenário SQLite de recuperação).

O renderer DANFE PDF A4 também foi validado com o novo quadro destacado de
contingência, incluindo `tpEmis`, justificativa e data/hora de ativação.

O cliente SEFAZ foi testado com envelopes SOAP 1.1 e 1.2; a versão 1.1 usa
namespace e `Content-Type: text/xml`, enquanto a versão padrão 1.2 usa
`application/soap+xml`.

## Atualização de integração Flutter

Foi adicionado `example_flutter/integration_test/offline_flow_test.dart` para
exercitar geração de NFC-e offline e persistência SQLite em dispositivo ou
simulador. O build do simulador iOS terminou localmente, mas a instalação via
`simctl` ficou bloqueada pelo runtime; essa execução não é contabilizada como
teste aprovado. Em 25/10/2026, o mesmo smoke test passou no emulador Android
`Medium_Phone` (`emulator-5554`), incluindo instalação do APK, execução Flutter
e persistência SQLite. `flutter analyze` e os testes Flutter de host continuam
aprovados. A CI agora repete o smoke test no job `flutter-android-integration`
com `reactivecircus/android-emulator-runner` e possui também o job
`flutter-ios-integration` para o iPhone Simulator em runners macOS.

O cenário XMLDSig do mesmo teste agora gera uma chave RSA efêmera em memória e
assina/verifica com RSA-SHA1 no runtime Flutter, em vez de usar um assinador
fictício.

O exemplo Flutter também foi validado com `flutter analyze` e `flutter test`
após passar a preparar um DANFE NFC-e em PDF pelo adaptador de saída injetável.
O smoke test no iPhone conectado sem fio não iniciou porque o Flutter exigiu
um canal de publicação para o dispositivo tethered; a versão local do comando
não oferece a opção `--publish-port`. A CI continua configurada para executar
o mesmo cenário em simuladores Android e iOS.

Os builds `flutter build apk --debug`, `flutter build ios --debug
--no-codesign` e `flutter build macos --debug` também foram repetidos após a
integração do PDF e concluíram com sucesso.

As fixtures executáveis foram validadas localmente com `xmllint` contra os
schemas incorporados: NF-e assinada, NFC-e offline, EPEC, inutilização,
comprovante de entrega, ator interessado e compra/exportação passaram nos
respectivos XSDs PL_009_V4/PL_010f.

A suíte agora inclui `test/xsd_examples_integration_test.dart`, que reproduz
automaticamente as quatro primeiras validações quando `xmllint` e os schemas
oficiais estão disponíveis; a execução local passou em 30 segundos.

O exemplo Flutter agora inclui `integration_test/xsd_platform_test.dart`, que
exercita um schema válido e uma rejeição através do parser nativo da plataforma.
Os testes de host dos adaptadores Android/iOS passaram, e os builds nativos
Android e iOS foram concluídos. A tentativa de executar o teste no iPhone
conectado sem fio foi bloqueada pelo requisito `--publish-port` da versão local
do Flutter. Em seguida, o mesmo `integration_test/xsd_platform_test.dart`
passou no iPhone 17 Pro Simulator iOS 26.3, cobrindo validação simples e
resolução de `xs:include` via `libxml2`; essa execução é contabilizada como
aprovada no simulador.

O teste de bundle também cobre recursos nomeados para `xs:include`/`xs:import`,
mantendo o caminho de schema único compatível e rejeitando explicitamente
bundles quando nenhum adaptador foi configurado.

Os jobs `flutter-android-integration` e `flutter-ios-integration` da CI agora
executam `integration_test/xsd_platform_test.dart` nos respectivos emulador e
simulador, além do fluxo offline existente.

## Auditoria NFePHP reproduzida

Com o snapshot `sped-nfe` fixado em `cf0baf005691c3a9e252314150c7dac18adbb2ee`
e `sped-common` `v5.1.17`, a auditoria executável confirmou 0 métodos ausentes
em `Make` (77 métodos) e `Tools` (20 métodos), equivalência estrutural de
`taginfNFe`/`tagide`/`tagemit`/`tagdest`/`tagprod`/`tagimposto`, superfícies de
`Complements`, `Standardize` e `Certificate` sem ausências, e 123 marcadores
TXT oficiais compatíveis. As diferenças legadas de campos vazios, `SEM GTIN`,
defaults tributáveis e nome de homologação são normalizadas explicitamente.

A execução completa mais recente (`dart test`) aprovou 368 testes, com apenas o
teste opt-in de homologação SEFAZ ignorado por ausência de credenciais externas.

A tabela de itens do DANFE A4 também foi revisada para identificar o preço
unitário corretamente e manter a mesma cardinalidade entre cabeçalhos e
valores fiscais emitidos.

O renderer PDF agora também foi validado em `DanfePdfLayout.a4Landscape`, além
do A4 retrato e da bobina NFC-e, preservando os blocos fiscais e o PDF válido.

Os blocos de informações adicionais dos DANFEs PDF e HTML foram validados com
separação entre informações complementares e reservado ao fisco.

O DANFE PDF também foi exercitado com as opções de apresentação alinhadas ao
`sped-da`: PIS/COFINS, tributos aproximados, informações adicionais de item e
e-mail do destinatário, título da via, casas decimais e filtros de observações
`obsCont`/`obsFisco`.

O leiaute A4 foi revisado para apresentar o bloco de transporte antes da
tabela de produtos/serviços, com o título fiscal correspondente; a suíte
completa permaneceu aprovada.

A assinatura XMLDSig RSA-SHA1 também foi verificada externamente com OpenSSL:
o `SignedInfo` canônico e a `SignatureValue` produzidos pelo núcleo foram
aceitos pela chave pública extraída do certificado X.509 do fixture A1.

O exemplo Flutter foi atualizado com `PlatformFiscalSecretStore`: o contrato
foi testado via `MethodChannel`, `flutter analyze` e `flutter test` passaram, e
os builds Android (`flutter build apk --debug`) e iOS (`flutter build ios
--debug --no-codesign`) compilaram as pontes nativas Android Keystore e iOS
Keychain. O uso efetivo do cofre em dispositivo ainda depende de execução
runtime na plataforma correspondente.

O teste `integration_test/offline_flow_test.dart` também cobre o round-trip
real de gravação, leitura e remoção no cofre nativo; em 26/10/2026 esse fluxo
passou no iPhone 17 Pro Simulator com iOS 26.3. Os jobs de integração Android
e iOS executam o mesmo cenário junto ao fluxo offline e ao XSD.

Na mesma revisão, a tabela passou a apresentar CST, NCM, CFOP, base/valor de
ICMS e valor de IPI por item, quando esses grupos estão disponíveis no modelo.

Também foi validada a marca destacada de documento cancelado no DANFE A4; a
opção é somente de apresentação e não representa o cancelamento perante a
SEFAZ.

O DANFE HTML recebeu as opções visuais de título, casas decimais e filtros de
`obsCont`/`obsFisco`, além de `DanfeHtmlOptions.canceled`, com regressão que
verifica essas opções e sua preservação como apresentação auxiliar.

Os renderizadores PDF e HTML também foram exercitados com protocolo/data de
EPEC, exibidos como registro auxiliar separado do protocolo de autorização.

O teste HTML também cobre as novas colunas fiscais de CST, base/valor de ICMS
e IPI por item.

A validação estrutural passou a conferir também o conteúdo de
`infNFeSupl/qrCode`, incluindo coerência da chave, ambiente, modalidade de
emissão, totais, data, destinatário, unicidade dos campos e formato da
assinatura dos perfis 2.00 e 3.00. Quando configurado, o validador também
confere criptograficamente a assinatura RSA-SHA1 do QR Code 3.00 offline
sobre os sete parâmetros definidos pelo manual; o teste do validador usa o
certificado A1 sintético do repositório para assinar e verificar de fato o
payload.

Os verificadores de compatibilidade NFePHP foram executados localmente contra
o commit `cf0baf005691c3a9e252314150c7dac18adbb2ee`: a superfície `Make` teve
77 métodos de referência sem ausências, `Tools` teve 20 métodos sem ausências,
e o relatório de assinaturas foi gerado com as divergências tipadas
documentadas. Com as dependências Composer do snapshot, também passaram os
verificadores de `Complements`, `Standardize`, `Certificate` e a comparação
estrutural de `Make::taginfNFe()`/`Make::tagide()`/`Make::tagemit()`/
`Make::tagdest()`/`Make::tagprod()`/`Make::tagimposto()`; nenhum método PHP de
referência ficou ausente.

Após a inclusão dos campos PL_010f `dPrevEntrega`/`cMunFGIBS`, da regra de
`cNF` diferente de `nNF` e dos perfis QR Code NFC-e 3.00 online/offline, a
suíte completa permaneceu aprovada com 333 testes. O exemplo de reforma
tributária que usa esses campos também foi gerado e validado contra o schema
PL_010f via `xmllint`.

O DANFE A4 também possui teste específico para o quadro detalhado de ISSQN,
com dados de serviço e retenção; a suíte direcionada do renderer aprovou 16
casos após essa inclusão.

O DANFE HTML foi alinhado ao PDF com quadro de ISSQN por serviço e fallback
para `ISSQNtot`; os testes HTML continuam aprovados.

O adaptador XSD em memória também possui `assertValidContent()`, com teste de
rejeição que confirma o código `XSD_VALIDATION_FAILED` sem simular um XML
válido quando o parser/adaptador retorna erro.

O exemplo Flutter também contém `AndroidXsdContentValidator`, implementado
com `MethodChannel` e `SchemaFactory` nativo do Android. O código configura
`ACCESS_EXTERNAL_DTD` e `ACCESS_EXTERNAL_SCHEMA` como vazios antes da
validação. O APK Android foi recompilado após essa ponte; a execução runtime
específica desse canal ainda não foi contabilizada nesta rodada.

Também foi adicionada a ponte `IosXsdContentValidator`, compilada contra o
`libxml2` do SDK iOS e usando `XML_PARSE_NONET`; o app iOS sem assinatura foi
recompilado com sucesso. Os testes Flutter cobrem o mapeamento de resultados
válidos e rejeitados dos dois canais, e o teste nativo de bundle passou no
iPhone 17 Pro Simulator com iOS 26.3. O runtime Android continua dependente
do emulador da CI nesta máquina.

Também foi adicionada a ponte `MacosXsdContentValidator`, compilada contra o
`libxml2` do SDK macOS e usando `XML_PARSE_NONET`. Em 26/10/2026, o build
macOS e `flutter test integration_test/xsd_platform_test.dart -d macos`
passaram, cobrindo validação em memória e bundle com `xs:include` em runtime.

O runner Linux também recebeu `LinuxXsdContentValidator`, ligado ao `libxml2`
por CMake. O build e o teste de integração serão executados no job Linux da CI;
este host macOS não permite executar `flutter build linux` localmente.

O runner Windows recebeu `WindowsXsdContentValidator`, baseado em MSXML6 com
DTD e recursos externos desabilitados. O build e o teste de integração ficam
configurados no job Windows da CI e não foram executados neste host macOS.

A renderização A4 foi convertida para PNG em 26/10/2026 e inspecionada
visualmente após o ajuste das larguras da tabela de itens e a reestruturação do
cabeçalho em três blocos fiscais (emitente, DANFE e chave/protocolo), o
quadro delimitado de destinatário e o quadro de cálculo do imposto em largura
total; o PDF gerado mantém formato A4 e duas páginas com cabeçalho de
continuação. A
diagramação completa de todos os blocos ainda não substitui integralmente o
`sped-da` oficial.

Após a dependência direta `barcode` usada pelo DANFE HTML, o exemplo Flutter
foi novamente validado com `flutter pub get`, `build_runner`, `flutter analyze`,
`flutter test` e `flutter build bundle --debug`, todos aprovados.

Após o endurecimento da validação XMLDSig e da API `Tools`, o exemplo Flutter
foi revalidado com `flutter pub get`, `flutter analyze`, `flutter test` e
`flutter build bundle --debug`, também sem falhas.

Em 26/10/2026, a matriz nativa local também gerou com sucesso o APK Android,
o app iOS sem assinatura e o app macOS; Linux e Windows foram deixados para os
runners nativos da CI por não serem alvos de build deste host macOS.

O exemplo Flutter foi ampliado com configuração demonstrativa de emitente,
produto, CSC e certificado A1 externo, pré-visualização DANFE HTML, fila
SQLite/Drift e indicação explícita das pré-condições de transmissão. Após a
alteração, `flutter analyze`, `flutter test`, `flutter build bundle --debug` e
`dart run build_runner build` passaram no exemplo.
O exemplo também prepara bytes ESC/POS e exibe histórico local das ações, sem
acoplar o núcleo a USB, Bluetooth ou driver de impressora.

O gate `dart run tool/verify_release_readiness.dart` passou, verificando 23
artefatos obrigatórios de publicação e sete invariantes de nome, segurança,
homologação, CI, rastreabilidade do exemplo Flutter e higiene do `.pubignore`.
O iPhone físico apareceu via conexão sem fio, mas o Flutter não iniciou o
smoke test sem a opção adicional `--publish-port`; essa tentativa não é
contabilizada como aprovada.
O smoke test no alvo macOS compilou o aplicativo, mas o runner não conseguiu
colocá-lo em primeiro plano (`open returned 1`); também não é contabilizado
como aprovado.

Em 25/10/2026, a regressão local contra o `sped-nfe` v5.0.100, commit
`cf0baf005691c3a9e252314150c7dac18adbb2ee`, também passou: a superfície
`Make` (77 métodos), a superfície `Tools` (20 métodos), a comparação estrutural
de `taginfNFe()`/`tagide()`/`tagemit()`/`tagdest()`/`tagprod()`/`tagimposto()`, o
inventário TXT (123 marcadores oficiais) e as superfícies `Complements`,
`Standardize` e `Certificate`. Campos vazios, `SEM GTIN`, defaults tributáveis e
nome de homologação são normalizados explicitamente como diferenças legadas de
representação.

O renderer DANFE também possui regressão específica para identificação fiscal
completa de emitente e destinatário nos formatos A4, HTML e texto.

## Última execução local

- `dart analyze`: aprovado, sem issues.
- `dart doc --validate-links`: aprovado sem warnings ou links quebrados; a API
  pública foi documentada em `doc/api`.
- `Certificate.writePfx()`: round-trip PFX validado pela própria biblioteca e
  contêiner exportado inspecionado com OpenSSL (`Shrouded Keybag`, 3DES e MAC
  SHA-1).
- A cobertura de DANFE inclui `DanfePdfOptions` para largura/margem, via
  resumida, via estabelecimento, cancelamento, segunda via offline e conteúdo
  adicional, fonte TTF/OTF fornecida pela aplicação, além da identificação
  fiscal da operação e contingência.
- `NfeTxtValidator` valida a estrutura local TXT 4.00, cardinalidade,
  terminadores, marcadores e caracteres proibidos.
- `NfeTxtConverter` também valida/converte as bases históricas `LOCAL_V12` e
  `SEBRAE` do NFePHP 4.00; a regressão SEBRAE cobre pagamentos, integração,
  troco e a normalização do produto.
- `tool/validate_avulsa_example.dart` gera uma NF-e com `avulsa` e o job Linux
  valida o resultado contra o schema PL_010f vigente.
- `NfeTxtConverter` cobre cabeçalho, participantes, produtos e ICMS/PIS/COFINS
  normais e variantes de desoneração/redução/diferimento, ICMS-ST incluindo
  `ICMS90`, Simples Nacional com crédito/ST/ICMS efetivo, NVE/CEST/escala,
  PIS/COFINS Outr por base/quantidade, `vTotTrib` do registro `M`, retirada/
  entrega, documentos referenciados, destinatário estrangeiro, IPI,
  importação, PIS-ST, COFINS-ST, ISSQN, cobrança,
  pagamentos, transporte e informações adicionais, incluindo divergências de
  `vProd` e `vNF`.
- `ContingencyXmlAdjuster` cobre ajuste de XML legado, remoção de assinatura
  obsoleta e recálculo da chave para reassinatura.
- O renderer DANFE PDF A4 cobre canhoto de recebimento opcional, com teste de
  renderização ativado e desativado.
- A inspeção visual via Quick Look confirma o canhoto no topo da primeira
  página, seguido do cabeçalho fiscal, destinatário, itens, transporte e
  totalizadores; páginas de continuação mantêm o rodapé de paginação.
- A inspeção visual também confirma a identificação `SEM VALOR FISCAL -
  AMBIENTE DE HOMOLOGAÇÃO` para documentos com `tpAmb=2`, no quadro superior
  do DANFE A4.
- O DANFE PDF A4 também cobre o detalhamento de transportador, veículo,
  reboques, volumes, lacres, retenção de transporte e observações fiscais
  identificadas no bloco de informações adicionais.
- A continuação A4 para muitos itens é exercitada com rodapé de paginação.
- O exemplo `tool/render_danfe_example.dart` foi renderizado localmente e
  inspecionado visualmente via Quick Look; a CI também verifica que o PDF é
  gerado com conteúdo não vazio.
- `test/sefaz_homologation_test.dart` prepara uma consulta real opt-in com mTLS
  A1; sem credenciais externas, o teste permanece explicitamente pulado.
- `dart test`: aprovado, 279 testes (incluindo `dhSaiEnt`/`departureDate` no XML e no conversor TXT, emitente CPF `C02A` e chave preenchida, emissão avulsa TXT `D`/`avulsa` e sua preservação nos renderizadores DANFE textual/HTML/PDF, fonte TTF/OTF configurável no DANFE PDF, nomes de locais TXT `F02B`/`G02B`, marcadores de agrupamento `N`/`Q`/`S`, total ISSQN legado `W17` com validação de valores/regime, IPI por unidade `O11`, ICMS-ST retido/destino `N10B`, `ICMSST` sem operação própria `N05`, ICMS10 `N10A` com `pBCOp`/`UFST`, responsável técnico `ZD`, suplemento NFC-e `ZX01`, exportação `ZA`, compra `ZB`, aquisição de cana `ZC`/`ZC04`/`ZC10`, referências `refNFP` com CNPJ/CPF de `BA13`/`BA14`, autorizações `autXML` de `GA02`/`GA03`, RECOPI `LB`, declarações de importação `DI`/`adi`, exportação `detExport/exportInd`, rastreabilidade `rastro`, medicamentos `med`, combustíveis ANP/CIDE/encerrante com `pBio`/`origComb`, veículos novos `veicProd`, armamentos `arma`, metadados comerciais de produto, transporte completo com `retTransp`, reboques `X22`, vagão `X25A`, balsa `X25B`, volumes/lacres, grupos `exporta`/`compra`/`cana`, compras governamentais `gCompraGov/refDFeAnt`, pagamento antecipado `gPagAntecipado`, comprovante de entrega `110130` com hash/GPS, evento de ator interessado `110150` com validação XSD, encoder ESC/POS com sanitização e comandos de impressão, verificação criptográfica opcional no validador XMLDSig, rejeição de item duplicado e valores não finitos, validação de identificador único, `indTot` e `vTroco`, roteamento por endpoint, versão e `SOAPAction` de cada operação SEFAZ, mapas de configuração e códigos de retry imutáveis, distribuição DF-e, consulta cadastral, consulta GTIN, download de NF-e, compactação GZIP `nfeDadosMsgZip`, claim atômico opcional da fila offline, falhas de rede normalizadas em `SEFAZ_NETWORK_ERROR`, `SEFAZ_SOAP_FAULT` preservando estado `unknown`, bloqueio de NFC-e offline no fluxo de autorização online, envelope estrutural de assinatura no validador anti-wrapping, rejeição de certificado A1 expirado antes de assinatura/mTLS, cópias defensivas dos buffers de certificado/chave privada, reserva concorrente de numeração offline, fábrica de chave por componentes e contingência NFC-e, política de repetição HTTP do cliente SEFAZ, configuração validada do cliente, EPEC, cancelamento por substituição `110112` via `Tools`, parser de `soap:Fault` como `SEFAZ_SOAP_FAULT`, assinatura de `envEvento` e `inutNFe`, assinatura automática de eventos pela fachada Tools, manifestações do destinatário, variantes de ICMS, CSOSN, monofásico, IPI, PIS/COFINS por quantidade, PISST/COFINSST com validação de combinações, IBS/CBS/Imposto Seletivo com diferimento/devolução/redução e validação de bases/alíquotas, compatibilidade Make, autorização SEFAZ síncrona/assíncrona, eventos e inutilização, contingência estrutural e fila com prazo de transmissão, transmissão posterior com resolução de `unknown`, validade X.509, leitura e exportação PFX/P12 por arquivo/bytes, round-trip PKCS#12, extração ICP-Brasil de CNPJ/CPF por OID, assinatura/verificação RSA textual com certificado/identidade, verificação da assinatura e cadeia X.509 RSA, rejeição segura de Base64 inválido em RSA SHA-1/SHA-256, QR Code SVG embutido no DANFE HTML, identificação da operação e contingência nos DANFEs HTML/PDF, totalizadores monetários/pagamentos estruturais, regra `indTot` no XML/validador/DANFE, fachada Tools, saídas callback/arquivo/TCP com validação de destino e comprimento dinâmico do DANFE NFC-e térmico, além do destinatário estrangeiro `E03A`, grupo TXT `K`, combustível `LA`/`LA07`/`LA11` e rastreabilidade `I80`, além do marcador oficial `B19`.
- `flutter test`: aprovado, 279 testes e 1 teste opt-in ignorado.
- Validação final após a regressão de cardinalidade: `dart test` também foi
  aprovado com 279 testes; a cobertura inclui os leiautes legado e estendido
  de `B` e `YA`.
- Execução final após a validação do modelo fiscal do cliente SEFAZ:
  `dart test` e `flutter test` aprovados com 280 testes; permanece apenas o
  teste opt-in de homologação real ignorado sem credenciais externas.
- Execução final após o adaptador XSD em memória: `dart test` e `flutter test`
  aprovados com 282 testes; `dart analyze` e `dart pub publish --dry-run`
  também passaram sem avisos.
- Execução final após o suporte à base TXT SEBRAE: `dart test` e `flutter test`
  aprovados com 283 testes; a homologação real continua sendo o único teste
  opt-in ignorado sem credenciais externas.
- Execução final após a identificação fiscal de homologação no DANFE:
  `dart test` e `flutter test` aprovados com 284 testes; análise e publicação
  seca também passaram sem avisos.
- Execução final após alinhar a indicação de homologação e `infAdic` entre os
  renderizadores DANFE textual e HTML: `dart test` e `flutter test` aprovados
  com 284 testes; `dart analyze` e `dart pub publish --dry-run` também passaram.
- Execução final após repetir a identificação fiscal nas páginas de continuação
  do DANFE A4: `dart test` e `flutter test` aprovados com 285 testes; análise
  e publicação seca também passaram.
- Execução final após tornar o cabeçalho de itens do DANFE HTML repetível na
  impressão multipágina: `dart test` e `flutter test` aprovados com 285 testes;
  análise e publicação seca também passaram.
- A fila offline agora valida integridade SHA-256 do XML persistido; o teste de
  corrupção e a migração Drift do exemplo passaram junto com a suíte do pacote.
- Execução final após persistir o digest SHA-256 na fila offline: `dart test` e
  `flutter test` aprovados com 286 testes; `dart analyze` e publicação seca
  também passaram sem avisos.
- Execução final após validar o digest no momento de reivindicar a transmissão:
  `dart test` e `flutter test` aprovados com 287 testes; análise e exemplo
  Flutter também permaneceram aprovados.
- Execução final após adicionar o decorador de integridade para backends
  customizados: `dart test` e `flutter test` aprovados com 288 testes;
  análise e publicação seca passaram sem avisos.
- Execução final após adicionar logotipo e margem A4 configurável ao DANFE PDF:
  `dart test` e `flutter test` aprovados com 289 testes; análise e publicação
  seca também passaram sem avisos.
- O logotipo também foi exercitado no cabeçalho térmico NFC-e e incluído no
  cálculo de comprimento da bobina; a suíte completa permaneceu com 289 testes
  aprovados e publicação seca sem avisos.
- Execução final após implementar a segunda via do DANFE NFC-e em contingência
  offline: `dart test` e `flutter test` aprovados com 290 testes; análise e
  publicação seca também passaram sem avisos.
- A marca d'água de homologação do DANFE NFC-e térmico foi exercitada junto
  com a suíte completa, que permaneceu com 290 testes aprovados e publicação
  seca sem avisos.
- Informações adicionais de item, lotes, medicamentos e tributos aproximados
  foram exercitadas nos renderizadores PDF/HTML; a suíte completa permaneceu
  com 290 testes aprovados e publicação seca sem avisos.
- A saída DANFE textual também passou a preservar esses dados; `dart test` e
  `flutter test` permaneceram com 290 testes aprovados, análise limpa e
  publicação seca sem avisos.
- A documentação API foi regenerada com `dart doc --output=doc/api`, sem
  warnings/errors; o índice inclui as APIs públicas recentes de integridade,
  DANFE e validação XSD.
- `dart run tool/verify_nfephp_api.dart` contra o `Make.php` do NFePHP v5.0.100:
  aprovado; os 77 métodos operacionais públicos da referência (78 incluindo o
  construtor PHP) possuem fachada Dart.
- `dart run tool/verify_nfephp_make.dart` com Composer e o NFePHP v5.0.100:
  aprovado; `taginfNFe()`, `tagide()`, `tagemit()`, `tagdest()`, `tagprod()` e
  `tagimposto()` produziram a mesma estrutura semântica após normalização
  explícita das diferenças legadas de representação.
- `dart run tool/verify_nfephp_tools_api.dart` contra `Tools.php` do NFePHP
  v5.0.100: aprovado; os 20 métodos públicos operacionais possuem fachada Dart,
  além dos aliases e extensões tipadas.
- `dart run tool/verify_nfephp_txt_layout.dart` contra `txtlayout400.md`:
  aprovado; os 123 marcadores oficiais estão cobertos, com `BA19` tratado como
  alias de `B19`.
- A regressão TXT cobre também as cardinalidades legadas e estendidas de `B` e
  `YA`, sem deslocar `procEmi`, `verProc`, contingência ou `xPag`.
- A regressão TXT cobre também `indIntermed`, `YB` e `xPag`/descrição de pagamento.
- `example_flutter`: `flutter pub get`, Drift `build_runner`, `flutter test` (3
  testes), `flutter analyze`, `flutter build bundle --debug`, `flutter build
  apk --debug`, `flutter build ios --debug --no-codesign` e `flutter build
  macos --debug` aprovados localmente;
  os testes verificam duas reservas consecutivas e a expiração de documento
  com prazo persistido no SQLite em memória.
- Validação adicional local: `flutter analyze` sem issues e `flutter test` com
  3 testes aprovados; o detalhamento de builds por sistema está em
  `PLATFORM_SUPPORT.md`.
- O exemplo Flutter também compila o alocador transacional de numeração Drift
  e a migração do banco para schema versão 3, incluindo `deadlineAt`.
- `dart pub publish --dry-run`: aprovado, 0 warnings.
- Fixture de comprovante de entrega `110130` gerada por
  `tool/validate_delivery_example.dart` e validada no CI contra
  `envEventoEntregaNFe_v1.00.xsd`, com assinatura XMLDSig sintética.
- CI GitHub Actions também executa `dart pub publish --dry-run` e verifica o
  manifesto de hashes do pacote PL_010f vigente antes dos testes de fixtures.
- A CI também gera e valida o exemplo monofásico assinado, incluindo
  `gpBioDiferenca` e os totais por item, contra o XSD PL_010f.
- O teste de integração Flutter também exercita a ponte Bluetooth ESC/POS em
  runtime, além do fluxo de persistência offline no emulador/simulador.
- A fila offline foi validada com reenvio idempotente no backend Drift/SQLite e
  rejeição de conflito para a mesma chave associada a XML diferente.
- O exemplo Flutter passou a preencher os campos mínimos de `ide`, emitente e
  processo (`natOp`, `tpNF`, `idDest`, `tpImp`, `finNFe`, `procEmi` e `verProc`)
  antes de persistir a contingência offline.
- A emissão demonstrativa agora reserva o número pela sequência transacional
  Drift, e a integração macOS aprovou os três cenários: SQLite/offline,
  Bluetooth ESC/POS e envelope XMLDSig.
- `XsdValidator` foi testado com executor injetável e valida existência dos
  arquivos antes de delegar ao `xmllint`; a ferramenta `validate_xsd.dart` usa
  o mesmo adaptador.
- O exemplo `tool/validate_monophase_example.dart` gera IBS/CBS monofásicos
  com `gpBioDiferenca` e totais por item e passa no XSD PL_010f_v1.04 via
  `xmllint`.
- DANFE HTML cobre também protocolo, situação, motivo e data de autorização;
  o PDF A4 exibe o mesmo bloco de protocolo quando o documento está
  protocolado.
- O teste de certificados confirma a extração da cadeia PFX e a construção do
  transporte HTTPS cliente com essa cadeia, sem desativar raízes confiáveis.
- A fixture de reforma tributária também cobre `gCred` e `tpCredPresIBSZFM` e
  valida esses campos contra o XSD vigente PL_010f.
- A mesma fixture cobre `cBarra`, `cBarraTrib`, `indEscala` e `CNPJFab`, com
  validação de ordem e dependência do CEST no PL_010f.
- A fixture de variantes de ICMS cobre `cBenefRBC` em ICMS51 e valida o XML no
  PL_010f.
- A fixture de reforma cobre `nRECOPI` com validação de 20 dígitos no PL_010f.
- A fixture de comércio cobre `indIntermed`/`cIndOp` e a identificação
  ampliada de participantes (`xFant`, complemento, telefone, IEST, IM, CNAE,
  SUFRAMA, `indIEDest` e e-mail), validando o XML no PL_010f.
- A mesma fixture cobre `refCTe` em `ide/NFref`, validado contra o PL_010f.
- A ferramenta `validate_tax_extensions.dart` gera fixture assinada com `II`,
  `PISST`, `COFINSST`, `ICMSUFDest`, `IS`, `IBSCBS`, `impostoDevol` e
  `retTrib`; essa fixture valida contra o `nfe_v4.00.xsd` oficial PL_010f.
- Os renderizadores PDF A4 e NFC-e térmico incluem código de barras Code 128
  da chave de acesso; a geração foi exercitada nos testes de DANFE.
- CI configurada com matriz Dart e Flutter do exemplo em Linux, macOS e
  Windows; além do bundle e dos testes, o job Linux constrói APK e Linux, o
  job macOS constrói iOS sem assinatura e macOS, e o job Windows constrói
  Windows. As validações XSD com `xmllint` permanecem no job Linux por
  dependerem desse utilitário.
- O job Linux também gera um EPEC assinado e valida o resultado contra
  `schemas/PL_009_V4/eventoEPEC_v1.00.xsd`.
- O job Linux também gera uma inutilização assinada e valida o resultado contra
  `schemas/PL_009_V4/inutNFe_v4.00.xsd`.
- O job Linux também gera um evento de prorrogação de retorno (`111500`) e
  valida o envelope contra `envEvento_v1.00.xsd`; os grupos específicos
  `detEvento` são cobertos pelos schemas `e111500`/`e111502` e pelos testes de
  compatibilidade da fachada `Tools`. O mesmo job gera e valida também o
  cancelamento (`111502`) e seus grupos `detEvento` específicos.
- O job Linux também gera uma NF-e assinada com `veicProd` e `arma` em itens
  distintos e valida o resultado contra o XSD PL_010b.
- O job Linux também gera uma NF-e assinada com IBS/CBS/Imposto Seletivo e
  valida a ordem desses grupos contra o XSD PL_010b.
- `flutter analyze` em `example_flutter`: aprovado, sem issues; exemplo Drift/SQLite gerado com `build_runner`.

## Cobertura atual

Os testes cobrem geração XML estrutural, suplemento `infNFeSupl` da NFC-e, campos comerciais e tributáveis do produto, DI/adi e detExport/exportInd de comércio exterior, grupos `veicProd`/`arma`, serviços com ISSQN/ISSQNtot (inclusive total legado TXT `W17`) e regras de exclusão de tributos de produto, rateios de frete/seguro/desconto/despesas/importação, campos `ide` derivados da chave e indicadores da operação, intermediador `infIntermed` com validação de coerência, grupos `exporta`/`compra`/`cana`, comparação normalizada com fixture executada contra NFePHP `v5.0.100`, montagem e assinatura integrada de NF-e e eventos, montagem e cálculo da chave de acesso, coerência de número/série/data/CNPJ com a chave, rejeição de chave inválida, fachada `Make`, validação de CPF/CNPJ/GTIN, utilitários de formatação, aritmética decimal exata e totalizadores, pagamentos com cartão, integração e troco, ICMS-ST/FCP, IPI tributado, grupos tributários básicos, IBS/CBS, IBS/CBS monofásicos ad rem padrão com retenção e retenção anterior e Imposto Seletivo percentual ou ad rem com unidade/quantidade, transporte sem ocorrência e com transportador/retenção/reboques/volumes/lacres com normalização de documentos/placa/UF, documentos referenciados, cobrança/duplicatas, responsável técnico, contingência, fixture XML, validação estrutural e semântica do XML, QR Code NFC-e 2.00 online/offline com SHA-1 e CSC, eventos de cancelamento, CC-e, EPEC e manifestações do destinatário, inutilização, distribuição DF-e, consulta cadastral, consulta GTIN, download de NF-e, transporte SOAP SEFAZ injetável, timeout, envio de lote, consulta de chave/protocolo, status e recibo, parser de retornos `cStat`/recibo/protocolo, leitura de certificado PEM/PFX com verificação de senha, conversão de chave RSA, `SecurityContext` mTLS, assinatura/verificação XML com identidade PFX, canonicalização C14N 1.0 inclusiva com namespaces herdados, namespace default vazio e instruções de processamento, proteção contra estruturas ambíguas em NF-e, eventos e inutilização, fila offline idempotente com estados e recuperação de falhas, reivindicação atômica concorrente direta no store em memória, adaptador SQLite/Drift do exemplo Flutter, DANFE textual/HTML/PDF com cobrança, informações adicionais, transporte e dados de consulta NFC-e, digest SHA-1/SHA-256, assinatura RSA/XML enveloped e cenários de segurança. O pipeline também gera XMLs fiscais assinados de NF-e, comércio exterior, produtos especiais e EPEC e valida esses resultados contra os schemas oficiais via `xmllint`.

O pacote histórico PL_010b_NT2025_002_v1.30 contém cinco XSDs que passam no parse do `xmllint`; ele não deve ser interpretado como o schema oficial vigente. O pacote oficial vigente `PL_010f_v1.04` foi incorporado, os cinco XSDs passam no parse e seis fixtures NF-e/NFC-e assinadas validam contra `nfe_v4.00.xsd`. O pacote legado PL_009_V4 contém um arquivo com bytes incompatíveis com a declaração UTF-8 (`retEnvConfRecebto_v1.00.xsd`), além de não haver validação XSD runtime multiplataforma. O fixture mínimo é corretamente rejeitado pelo schema. Também permanecem pendentes comunicação autorizadora real, diagramação oficial completa do DANFE e autorização fiscal; esses itens não devem ser tratados como cobertos.

Os testes de compatibilidade da fachada `Tools` também cobrem administração do
CSC NFC-e e combinação de dois eventos em um `envEvento` de lote; o limite de
20 eventos é validado na API antes do envio.

