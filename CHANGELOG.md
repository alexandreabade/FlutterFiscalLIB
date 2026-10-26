# Changelog

## 0.1.1 - 2026-10-26

- Primeira versão incremental após a publicação inicial no pub.dev.

- Adicionado `FiscalCompanyRegistration` e `SefazEndpointCatalog`, com catálogo
  de endpoints/action SOAP por UF, modelo e ambiente, além de geração automática
  do QR Code NFC-e 2.00/3.00; incluído o exemplo
  `example/bin/cadastro_empresa_nfce.dart`.
- A fachada `Make` passou a cobrir `setCalculationMethod`, `setCheckGtin` e
  `render`, com validação configurável de GTIN e testes de compatibilidade.
- A fachada `Tools` passou a cobrir os eventos NFePHP de insucesso na entrega
  (`110192`/`110193`) e conciliação financeira (`110750`/`110751`), com
  builders tipados e validações próprias.
- O comprovante de entrega passou a suportar também o cancelamento `110131`,
  com protocolo obrigatório e teste específico.
- Corrigido o renderer HTML para que `showItemAdditionalInfo: false` também
  oculte dados de medicação, mantendo a mesma semântica do PDF.
- O renderer HTML passou a expor `showItemAdditionalInfo` e
  `showItemTraceability`, mantendo o controle de detalhes dos itens alinhado
  ao DANFE PDF.
- O DANFE passou a expor `DanfePdfOptions.showItemTraceability`, mapeando
  `descProdInfoLoteTxt` do `sped-da` para controlar separadamente lote,
  fabricação e validade na descrição dos itens.
- O carregamento de identidades A1 agora comprova criptograficamente que a
  chave privada do PFX corresponde ao certificado X.509, com fixture sintética
  de incompatibilidade e teste de regressão.
- Adicionado um smoke test da superfície pública do entrypoint, cobrindo os
  principais tipos de XML, tributos, assinatura, SEFAZ, contingência, DANFE,
  validação, compatibilidade e saída fiscal.
- O gate de release passou a exigir `DANFE_COMPATIBILITY.md`, garantindo que a
  matriz de compatibilidade do `sped-da` acompanhe todos os pacotes publicados.
- O adaptador XSD Windows agora protege também o carregamento do schema contra
  DTD/entidades externas, rejeita schema temporário inválido e verifica falhas
  de escrita, criação de recursos e limpeza dos arquivos temporários usados pelo
  MSXML6.
- A matriz `DANFE_COMPATIBILITY.md` foi adicionada para rastrear a superfície
  pública de `sped-da` (`Danfe`/`Danfce`), seus mapeamentos tipados, a opção de
  fonte Unicode por bytes e as diferenças ainda abertas de geometria PDF.
- O cabeçalho DANFE A4 passou a identificar `FOLHA 1` e as páginas de
  continuação exibem a folha corrente, mantendo o rodapé com a paginação total.
- O DANFE PDF A4 passou a usar, por padrão, separadores verticais tracejados
  na tabela de itens, alinhando `DanfePdfOptions.useDashedItemSeparators` ao
  `setUsarLinhaTracejadaSeparacaoItens()` do `sped-da`, com opção de desativar
  o estilo para impressoras que exigem linhas contínuas.
- Os comandos do exemplo Flutter e da CI foram atualizados para o `build_runner`
  vigente, removendo a opção obsoleta `--delete-conflicting-outputs` e evitando
  avisos durante a geração do Drift.
- O fluxo de autorização SEFAZ passou a oferecer `NfeEmissionService.authorizeAndAwait()`
  para envio assíncrono com consulta do recibo sem reenviar o lote, limite de
  tentativas e retorno do último estado ainda desconhecido para persistência e
  continuação posterior; o cenário `cStat=105` também foi coberto para
  impedir reenvio quando o lote permanece em processamento e preservar o
  recibo original quando a SEFAZ não o repete na consulta.
- A resolução explícita de documentos NFC-e `unknown` agora preserva o recibo e
  o protocolo já persistidos quando a resposta de consulta não os repete.
- O polling assíncrono também preserva a chave do documento quando o retorno
  do recibo não contém `chNFe`.
- O DANFE PDF A4 passou a ordenar os quadros conforme o modelo de referência
  da NT 2026.010: cobrança, totais gerais, Total do IBS/CBS/IS, ISSQN,
  transporte/volumes e produtos/serviços, mantendo pagamentos e informações
  adicionais depois do detalhamento. A mudança aproxima a saída auxiliar do
  leiaute oficial vertical e paisagem sem declarar equivalência integral ao
  `sped-da`; o cabeçalho também reserva os campos de IE, IEST, CNPJ/CPF, CRT
  e regime de apuração futuro do IBS/CBS.
- O DANFE PDF A4 passou a incluir um quadro explícito de detalhamento IBS/CBS/IS
  por item, com classificação tributária, base, alíquotas, valores e valores
  monofásicos/retidos quando informados, sem inferir dados ausentes do XML.
- O DANFE HTML passou a seguir a mesma sequência de apresentação do PDF,
  colocando cobrança, totais, RTC, ISSQN e transporte antes da tabela de
  produtos/serviços, mantendo pagamentos em quadro próprio.
- O DANFE HTML passou a incluir também o quadro estruturado IBS/CBS/IS por
  item, com classificação, base, alíquotas, valores e retenções monofásicas.
- Os DANFEs passaram a exibir os identificadores fiscais adicionais do
  emitente e do participante quando informados: IEST, IM, CNAE, SUFRAMA e
  indicador de inscrição estadual do destinatário.
- Os totalizadores `IBSCBSTot` foram conferidos contra o tipo
  `TIBSCBSMonoTot` usado pelo leiaute NF-e PL_010f, mantendo os campos de
  crédito presumido exigidos na sequência oficial.
- Os totalizadores XML passaram a somar os valores informados de desoneração do
  ICMS, diferimento/devolução do IBS/CBS e créditos presumidos, eliminando zeros
  fixos em `ICMSTot/vICMSDeson` e `IBSCBSTot`.
- O grupo RTC `gEstornoCred` passou a ser aceito no item e totalizado em
  `IBSCBSTot`, conforme a sequência PL_010f.
- O crédito presumido RTC `gCredPresOper` passou a possuir modelo próprio para
  IBS/CBS, valores condicionais e totalização separada do `gCred` legado.
- O crédito presumido IBS da ZFM (`gCredPresIBSZFM`) passou a emitir competência,
  classificação e valor no grupo RTC, com totalização e validação de conflito.
- O indicador de doação RTC (`indDoacao`) passou a ser modelado e emitido na
  posição oficial do grupo IBS/CBS.
- A tributação regular RTC (`gTribRegular`) passou a ser modelada e emitida
  dentro de `gIBSCBS`, com validação de códigos, alíquotas e valores.
- A tributação sem redutor para compras governamentais (`gTribCompraGov`) passou
  a ser modelada e emitida na sequência oficial do `gIBSCBS`.
- Os DANFEs PDF e HTML passaram a apresentar no detalhe do item os grupos RTC
  condicionais e no quadro de totais os créditos presumidos e estornos de IBS/CBS.
- O campo `nFCI` foi adicionado ao item fiscal, com fachada `tagnFCI()` e
  validação do GUID hexadecimal exigido pelo PL_010f.
- Os campos `tpNFDebito` e `tpNFCredito` foram adicionados ao `ide`, com os
  códigos oficiais de notas de débito e crédito do PL_010f.
- Os campos de produto `indBemMovelUsado`, `infProdNFF` e `infProdEmb` foram
  adicionados conforme a ordem e os limites do PL_010f.
- O ICMS51 passou a suportar o diferimento do FCP (`pFCPDif`, `vFCPDif` e
  `vFCPEfet`) com validação de consistência.
- A desoneração do ICMS passou a suportar `indDeduzDeson` nos CST do PL_010f,
  com validação de dependência e emissão na ordem do schema.
- O CST 70 passou a ser emitido como `ICMS70`, incluindo redução de base,
  FCP e desonerações próprias e de ICMS-ST.
- O `ICMS90` passou a emitir também as desonerações própria e de ICMS-ST
  previstas no PL_010f.
- O `ICMS60` passou a emitir ICMS substituto, FCP-ST retido e valores efetivos
  conforme o leiaute PL_010f.
- O quadro de totais do DANFE HTML foi alinhado ao PDF, incluindo bases e
  valores de ICMS/ICMS-ST, seguro, II e outras despesas acessórias.
- Os totais do DANFE passaram a exibir também FCP-ST retido (`vFCPSTRet`)
  quando informado pelo grupo de ICMS-ST retido.
- O totalizador XML `ICMSTot/vFCPSTRet` passou a somar os valores retidos dos
  itens, em vez de emitir sempre `0.00`.
- As tabelas de itens dos DANFEs passaram a exibir GTIN/EAN e códigos de barra
  comerciais/tributáveis; a opção de pedido também mostra `xPed` e `nItemPed`.

- O DANFE PDF/HTML passou a representar no quadro RTC a base, alíquotas e
  valores de IBS/CBS/IS por item, além dos totais de IBS/CBS monofásicos
  retidos, usando a alíquota efetiva quando houver redução.
- Os renderizadores passaram a separar o quadro `Total do IBS/CBS/IS` do
  quadro geral de totais, com os oito campos consolidados previstos na NT
  2026.010.
- Os totais gerais do DANFE passaram a exibir ICMS monofásico próprio e retido
  quando presentes no item.
- A tabela fiscal do DANFE PDF passou a usar larguras flexíveis no A4 retrato e
  paisagem, aproveitando a área horizontal adicional do leiaute alternativo.
- Os totais gerais do DANFE passaram a exibir FCP próprio e FCP-ST quando
  informados.
- `verifyDigest()` agora exige uma referência XMLDSig única, explícita e
  compatível com o `Id` de `infNFe`, rejeitando URI divergente e IDs duplicados
  antes de aceitar o digest; o caso de wrapping possui teste de segurança.
- Os DANFEs PDF e HTML passaram a exibir CRT do emitente e classificações
  tributárias IBS/CBS/IS por item sempre que os dados estiverem presentes;
  `showItemTaxDetails` continua reservado aos detalhes complementares,
  aproximando a representação da NT 2026.010 sem inventar classificações.
- A matriz de referências passou a registrar a NT 2026.010, que divulga o
  modelo de DANFE para RTC; a documentação mantém explícita a diferença entre
  esse modelo oficial ainda pendente e o DANFE auxiliar atual.
- O manifesto de referências passou a registrar a consulta oficial de
  26/10/2026, distinguindo o pacote `PL_010f_v1.04` incorporado das revisões
  posteriores das Notas Técnicas ainda não incorporadas ao código e aos XSDs.
- O gate de release passou a garantir que `example_flutter/` não seja
  ignorado pelo Git, mantendo o exemplo rastreável no repositório enquanto o
  `.pubignore` continua excluindo-o do pacote publicado.
- A fila offline agora limpa `cStat`, recibo e protocolo antigos ao reabrir
  explicitamente um documento `unknown`, evitando metadados de uma tentativa
  anterior em uma nova transmissão.
- O parser SEFAZ passou a preservar todos os protocolos `infProt` de um lote,
  incluindo resultados mistos de autorização e rejeição, em
  `SefazResult.protocols`, mantendo os campos singulares retrocompatíveis.
- Respostas HTTP de erro que contêm `SOAP Fault` agora preservam a mensagem
  retornada pela SEFAZ e geram `SEFAZ_SOAP_FAULT`, sem expor o XML bruto.
- O cliente SEFAZ passou a validar o XML da operação antes de montar o
  envelope SOAP, evitando transmitir payloads malformados e retornando
  `INVALID_SEFAZ_XML` sem chamar o transporte.
- O job Flutter Linux da CI passou a instalar `xvfb` e executar o teste de
  integração XSD com display virtual, evitando falhas por ausência de sessão
  gráfica no runner.
- A geração automática de informações do DANFE passou a descrever também
  referências NF legadas, produtor rural e ECF, além de NF-e/CT-e.
- Adicionada a opção `showItemTaxDetails`, equivalente a
  `descProdInfoComplemento` do `sped-da`, para incluir tributos aproximados e
  benefício fiscal na descrição dos itens do DANFE.
- O DANFE HTML passou a permitir exibir PIS/COFINS e ocultar a linha de
  tributos aproximados por meio de `DanfeHtmlOptions`.
- Os totalizadores DANFE PDF e HTML passaram a exibir os valores de
  `ICMSUFDest` para UF de destino, UF de origem e FCP, controlados por
  `showInterstateTaxes`.
- Adicionada a opção `showPurchaseOrderItem`, equivalente a
  `exibirNumeroItemPedido` do `sped-da`, nos renderizadores DANFE PDF e HTML.
- Os renderizadores DANFE passaram a oferecer `showBillingText`, equivalente a
  `exibirTextoFatura` do `sped-da`, para exibir pagamento, fatura, desconto e
  valor líquido quando não existem duplicatas.
- Adicionada a opção `generateAutomaticInfo` aos renderizadores DANFE, que
  reproduz a geração opt-in do `sped-da` para nota de empenho, pedido, contrato,
  documentos referenciados e valor aproximado dos tributos.
- Os renderizadores DANFE PDF e HTML passaram a exibir, quando informados,
  unidade, quantidade e preço tributáveis (`uTrib`/`qTrib`/`vUnTrib`), com a
  opção `showTaxableUnit` para reproduzir o modo resumido do `sped-da`.
- Os renderizadores DANFE PDF e HTML passaram a aceitar protocolo e data de
  registro EPEC, mantendo essa informação separada da autorização normal.
- O exemplo Flutter passou a validar XSD em memória e bundles no macOS por
  `libxml2` nativo, com `XML_PARSE_NONET` e cenário de integração na CI.
- O runner Linux passou a oferecer o mesmo canal XSD nativo via `libxml2`, com
  build e teste de integração configurados no job Linux da CI.
- O runner Windows passou a oferecer validação XSD nativa via MSXML6, com DTD e
  recursos externos desabilitados e teste de integração configurado na CI.
- O DANFE PDF passou a expor opções compatíveis com configurações do
  `sped-da`: título da via, casas decimais de quantidade/preço e filtros para
  observações `obsCont` e `obsFisco`, preservando o núcleo fiscal imutável.
- O DANFE HTML passou a oferecer as mesmas opções de título, precisão de
  quantidade/preço e visibilidade de observações do renderer PDF.
- A regressão executável contra o NFePHP passou a comparar também `emit`,
  `dest`, `prod` e `imposto`, além de `infNFe`/`ide`, com normalização explícita
  para campos vazios, `SEM GTIN`, defaults tributáveis e nome de homologação.
- O cliente SEFAZ passou a aceitar SOAP 1.1 e SOAP 1.2 configuráveis por
  `SefazSoapVersion`, incluindo o `Content-Type` HTTP correto; SOAP 1.2 segue
  como padrão.
- Adicionado `.pubignore` e uma verificação correspondente ao gate de release
  para excluir artefatos locais, documentação HTML gerada e o app Flutter do
  arquivo publicado; o dry-run do pub.dev passou sem warnings.
- O DANFE PDF A4 passou a exibir um quadro destacado de contingência com
  modalidade, justificativa e instante de ativação, alinhado ao aviso exigido
  pelos layouts auxiliares oficiais.
- A fila NFC-e passou a persistir `transmittingAt` e a reconciliar leases
  abandonados após reinício/queda de energia como `unknown`, exigindo consulta
  explícita à SEFAZ antes de qualquer reenvio; o exemplo Drift recebeu a
  migração de schema correspondente.
- Adicionado ao exemplo Flutter o `PlatformFiscalSecretStore`, com Android
  Keystore/AES-GCM e iOS Keychain para persistência de PFX, senhas e outros
  bytes sensíveis sem acoplar o núcleo fiscal a plugins.
- Adicionados controles de apresentação ao DANFE PDF para PIS/COFINS, tributos
  aproximados, informações adicionais de item e e-mail do destinatário,
  alinhados às opções equivalentes do `sped-da`.
- Ajustada a ordem do DANFE PDF A4 para apresentar transporte antes dos
  produtos e identificado o quadro oficial “Dados dos produtos / serviços”.
- Adicionada ferramenta de regressão que valida a `SignatureValue` XMLDSig
  RSA-SHA1 com OpenSSL, além do verificador interno PointyCastle.
- Os renderizadores DANFE PDF e HTML passaram a separar visualmente
  “Informações complementares” de “Reservado ao fisco”, preservando processos,
  autorizações e observações fiscais nos respectivos blocos.
- Adicionado o layout público `DanfePdfLayout.a4Landscape` para NF-e, mantendo
  os mesmos blocos fiscais e cabeçalhos de continuação do renderer A4.
- Adicionada ao exemplo Flutter uma ponte Android `MethodChannel` para
  validação XSD em memória, com bloqueio de DTD e schemas externos; o núcleo
  continua recebendo validadores XSD por injeção em outras plataformas.
- Adicionada ao exemplo Flutter uma ponte iOS `MethodChannel` sobre `libxml2`
  do SDK, com validação XSD em memória e bloqueio de rede no parser.
- Adicionado suporte a bundles XSD com recursos nomeados para resolver
  `xs:include`/`xs:import` em validadores móveis, mantendo a API de conteúdo
  simples compatível.
- Adicionado teste de integração XSD que gera e valida NF-e assinada, NFC-e
  offline, EPEC e inutilização contra os schemas oficiais quando `xmllint`
  está disponível.
- A tabela de itens do DANFE HTML passou a exibir CST, base/valor de ICMS e
  valor de IPI, alinhando sua informação fiscal ao renderer PDF.
- `DanfeHtmlRenderer` passou a aceitar `DanfeHtmlOptions.canceled` e a exibir
  uma marca visual destacada de documento cancelado sem alterar o documento
  fiscal.
- O DANFE A4 passou a exibir uma marca fiscal destacada quando a opção
  `DanfePdfOptions.canceled` é usada, sem alterar o XML ou o estado SEFAZ.
- Aproximada a tabela de itens do DANFE A4 ao leiaute fiscal do `sped-da`, com
  CST, NCM, CFOP, base/valor de ICMS e valor de IPI por item.
- O exemplo Flutter passou a gerar DANFE NFC-e térmico e a entregar o PDF
  pelo `PdfFiscalOutputAdapter`, mantendo HTML e ESC/POS como fluxos separados.
- Corrigido o cabeçalho da coluna de preço unitário na tabela de itens do
  DANFE A4, mantendo o alinhamento com os 12 valores fiscais emitidos por
  item.
- Adicionado `PdfFiscalOutputAdapter` para entregar jobs PDF a integrações
  Flutter de impressão, compartilhamento ou canais nativos sem acoplar o
  núcleo a um plugin específico.
- Adicionado suporte aos perfis QR Code NFC-e 3.00 online e offline do Manual
  DANFE NFC-e 6.0: o modo online usa `chave|3|tpAmb` e o modo offline assina
  os parâmetros com RSA-SHA1, sem CSC. O perfil 2.00 continua disponível.
- O `NfeXmlValidator` passou a validar semanticamente `infNFeSupl/qrCode`,
  conferindo chave, ambiente, modalidade de emissão, data, total, destinatário
  e assinatura nos perfis NFC-e 2.00 e 3.00.
- O validador também rejeita `qrCode` e `urlChave` duplicados no mesmo
  `infNFeSupl`, evitando estruturas fiscais ambíguas antes do XSD externo.
- `NfeXmlValidator` aceita `XmlSignatureVerifier` opcional para verificar a
  assinatura RSA-SHA1 do QR Code 3.00 offline sobre os sete parâmetros
  assinados, além da validação estrutural/Base64.
- Reexecutada localmente a regressão de superfície e assinaturas `Make`/`Tools`
  contra o commit NFePHP v5.0.100 fixado, sem métodos de referência ausentes.
- A regressão local foi ampliada para `Complements`, `Standardize`, `Certificate`
  e equivalência estrutural de `taginfNFe`/`tagide`, também sem ausências na
  superfície PHP de referência.
- Ajustada a geometria da tabela de itens do DANFE PDF A4 com larguras fiscais
  proporcionais e cabeçalhos compactos, reduzindo quebras artificiais na
  renderização; a inspeção visual da página A4 foi registrada no relatório.
- Reestruturado o cabeçalho A4 em blocos fiscais inspirados no `sped-da`, com
  identificação do emitente, DANFE, entrada/saída, número/série, chave de
  acesso em Code 128, natureza da operação e protocolo.
- O bloco de destinatário/remetente do DANFE A4 passou a usar quadro fiscal
  delimitado, com documento, IE, endereço e contatos.
- O DANFE A4 passou a organizar os totalizadores em quadro de cálculo do
  imposto de largura total, incluindo bases ICMS/ICMS-ST, valores clássicos,
  IBS/CBS, imposto seletivo, retenções e valor da nota.
- O DANFE A4 passou a renderizar quadro detalhado de ISSQN para itens de
  serviço e para `ISSQNtot`, com código/lista, município do fato gerador,
  competência, base, alíquota, valor e retenção.
- O DANFE HTML passou a renderizar o mesmo quadro detalhado de ISSQN para
  serviços, preservando o fallback para `ISSQNtot` legado.
- `XsdValidator` passou a oferecer `assertValidContent()` para adaptadores
  XSD em memória, com a mesma exceção `XSD_VALIDATION_FAILED` do caminho
  baseado em `xmllint`.

- O modelo `NfeDocument` passou a emitir `dPrevEntrega` e `cMunFGIBS` do
  leiaute PL_010f, com validação do código IBGE de IBS/CBS; a composição da
  chave também rejeita `cNF` igual ao número da NF-e/NFC-e, conforme a regra
  de montagem do NFePHP.

- Adicionado `NfeXmlBuilder.buildStrict()`, que valida os campos fiscais
  mínimos de identificação, emitente, processo e operação antes de montar o
  XML, mantendo assinatura e validação XSD como etapas explícitas.
- O fluxo `NfeEmissionService.buildAndSign()`/`authorize()` passou a usar a
  montagem estrita antes da assinatura XMLDSig e do envio à SEFAZ.
- A preparação de NFC-e offline passou a usar a mesma montagem estrita antes
  da assinatura local e da persistência na fila de contingência.
- O DANFE HTML passou a incorporar o código de barras Code 128 da chave de
  acesso em SVG, além do texto e do QR Code NFC-e.
- As tabelas de itens dos DANFEs PDF e HTML passaram a exibir frete, desconto
  e tributos aproximados por item.
- A via térmica NFC-e passou a imprimir consumidor identificado, meios de
  pagamento detalhados e troco quando informados.
- A saída textual DANFE passou a preservar os mesmos dados de consumidor,
  pagamentos detalhados e troco.
- A via térmica NFC-e passou a exibir natureza da operação e protocolo de
  autorização quando disponíveis.
- O fluxo de autorização agora rejeita documentos cujo modelo não coincide
  com o modelo configurado no cliente SEFAZ.
- A CI passou a validar links da documentação Dart antes da publicação seca.
- Adicionado inventário reproduzível das assinaturas PHP de `Make` e `Tools`,
  comparando parâmetros da referência com as fachadas Dart e executado na CI.
- Reforçada a segurança: validação assinada exige verificador criptográfico,
  algoritmos XMLDSig desconhecidos são rejeitados e exportação PKCS#12 exige
  no mínimo 2048 iterações.
- Adicionada regressão explícita para algoritmos XMLDSig desconhecidos no
  verificador de digest.
- Documentada a matriz de licenças e termos dos schemas incorporados.
- A CI passou a verificar os manifests PL_009, PL_010b e PL_010f.
- O verificador de manifests passou a aceitar hashes agregados legados com
  ordenação determinística.
- Adicionado smoke test Flutter de integração para geração de NFC-e offline e
  persistência SQLite em dispositivo/simulador.
- A CI passou a executar o smoke test em um emulador Android, além da etapa de
  compilação do APK.
- A CI passou a executar o smoke test também em um iPhone Simulator no macOS,
  sem declarar homologação em dispositivo físico.
- A matriz de compatibilidade passou a registrar `montaNFe()` como equivalente
  estrutural ao alias `monta()` do NFePHP, com assinatura e XSD documentados
  como etapas separadas.
- Corrigida a análise de referências para marcar o registro de licenças dos
  schemas como concluído.
- Adicionado `FiscalSecretStore` com adaptador por callbacks para Keychain,
  Keystore e plugins de armazenamento seguro, além de cobertura de cópias
  defensivas e validação de chaves.
- Alinhada a restrição de SDK do exemplo Flutter com o pacote principal
  (`^3.12.0`).
- O DANFE A4 passou a exibir complemento, bairro, IE, UF, CEP, telefone e
  e-mail nos quadros de emitente e destinatário, com teste de regressão.
- DANFE HTML e textual passaram a preservar os mesmos dados de identificação
  fiscal e contato de emitente/destinatário.
- Documentado no README o uso de `FiscalSecretStore` para integrar cofres
  seguros de certificados em aplicações Flutter.
- `ContingencyXmlAdjuster` passou a aceitar emitentes identificados por CPF,
  mantendo a recomposição correta da chave de contingência.
- Reforçada a validação de contingência: NFC-e modelo 65 aceita somente
  emissão normal ou offline `tpEmis=9`; FS/SVC continuam disponíveis para NF-e.
- Adicionada regressão direta no `NfeXmlValidator` para rejeitar FS/SVC em
  NFC-e modelo 65.
- Adicionado `HOMOLOGATION.md` com o procedimento opt-in de status SEFAZ,
  pré-requisitos e limitações da homologação real.
- Reexecutada a regressão local contra o `sped-nfe` v5.0.100 fixado, cobrindo
  as superfícies `Make`/`Tools`, `taginfNFe()`/`tagide()` e o layout TXT.
- Ampliada a regressão da fachada `Tools` para status, recibo, distribuição
  DF-e, download, cadastro e EPEC.
- Adicionado verificador CI para as superfícies `Complements`, `Standardize` e
  `Certificate` do NFePHP, com normalização explícita de `__toString`.
- Ampliado o exemplo Flutter com configuração demonstrativa, carregamento
  externo de A1, campos de CSC, pré-visualização DANFE HTML e indicação segura
  das pré-condições de transmissão.
- O exemplo Flutter passou a preparar ESC/POS e exibir histórico local das
  ações, mantendo impressão física como adaptador da aplicação.
- Adicionado o gate `verify_release_readiness.dart` à CI para verificar
  artefatos obrigatórios, identidade do pacote e documentação de publicação.
- DANFE A4 passou a exibir locais fiscais de retirada/entrega e totalizadores
  visuais de IBS, CBS e Imposto Seletivo, com regressão dedicada.
- DANFE HTML e textual passaram a preservar locais fiscais e os valores de
  IBS, CBS e Imposto Seletivo, com regressões correspondentes.
- DANFE A4 e HTML passaram a exibir também os totalizadores de IBS/CBS
  monofásicos por item.
- Adicionada a ponte `BluetoothFiscalOutputAdapter`, que entrega bytes ESC/POS
  ao plugin Flutter sem acoplar o núcleo a um SDK nativo.
- A fila NFC-e passou a tratar reenvio do mesmo XML pela mesma chave como
  operação idempotente e rejeitar conflitos de XML com `CONFLICTING_DOCUMENT_ID`.
- O DANFE textual passou a exibir os valores de IBS/CBS monofásicos por item,
  alinhado aos renderizadores PDF e HTML.
- O exemplo Flutter passou a gerar contingência offline com os campos mínimos
  de identificação da operação, emitente e processo preenchidos.
- Os DANFEs PDF, HTML e textual passaram a preservar ISSQN declarado e
  retenções federais no resumo auxiliar.
- O exemplo Flutter passou a reservar números offline pelo alocador transacional
  Drift e a integração multiplataforma passou a cobrir XMLDSig e Bluetooth.
- A fila offline passou a resolver também a corrida entre `find` e `insert` em
  backends transacionais, relendo o registro concorrente para manter idempotência.
- Corrigida a canonicalização XMLDSig C14N inclusiva para namespaces herdados,
  remoção de namespace default e instruções de processamento, com regressões
  dedicadas.
- O store offline em memória passou a serializar reivindicações atômicas
  concorrentes diretamente, com regressão contra dupla transmissão.
- Assinatura e verificação de eventos e inutilizações passaram a exigir
  `infEvento`, `infInut` e `Signature` em posições diretas únicas, reforçando
  a proteção contra XML Signature Wrapping.
- O Imposto Seletivo passou a aceitar emissão ad rem com `adRemIS`, `uTrib` e
  `qTrib`, cálculo decimal da quantidade e validação da combinação dos campos;
  o exemplo da reforma continua validando no XSD PL_010f.
- Adicionado o grupo opcional `IbsCbsMonophaseTax` para monofasia ad rem
  padrão de IBS/CBS, com `CST 620`, classificação informada pela aplicação,
  exclusividade frente ao grupo regular e totalização fiscal.
- A monofasia ad rem passou a emitir também retenção (`gMonoReten`), retenção
  anterior (`gMonoRet`) e seus totalizadores `gMono` para IBS/CBS.
- A monofasia padrão passou a aceitar também os grupos ad valorem de IBS/CBS,
  com base, alíquotas e valores estaduais/municipais conforme a NT 2025.002.
- A monofasia passou a emitir os totais por item exigidos pelo PL_010f e o
  grupo `gpBioDiferenca` para diferenças de mistura de biocombustível; o novo
  exemplo também é validado com `xmllint` contra o XSD oficial versionado.

- Documentação API Dart regenerada em `doc/api`, incluindo as APIs públicas
  recentes de integridade, DANFE e validação XSD, sem warnings do dartdoc.
- DANFE PDF e HTML passaram a exibir informações adicionais de item, lotes,
  medicamentos e total de tributos aproximados quando informados.
- A saída textual do DANFE passou a preservar os mesmos dados adicionais de
  item e tributos aproximados.
- As representações DANFE textual e HTML passaram a exibir a mesma indicação
  de homologação e todas as observações identificadas em `infAdic`.
- O DANFE A4 passou a repetir a identificação do documento e da série nas
  páginas de continuação, preservando a referência fiscal durante a impressão.
- O DANFE HTML passou a usar cabeçalho de itens repetível na impressão
  multipágina, com chave de acesso e proteção contra quebra de itens.
- Registros da fila offline passaram a persistir digest SHA-256 do XML; o store
  em memória e o exemplo Drift rejeitam registros cujo conteúdo foi alterado.
- Adicionado `IntegrityCheckingFiscalDocumentStore` para aplicar a checagem de
  digest automaticamente em backends de persistência fornecidos pela aplicação.
- `DanfePdfOptions` passou a aceitar logotipo do emitente por bytes e margem A4
  configurável, mantendo a saída independente de arquivos e plugins.
- O mesmo logotipo passou a ser exibido no cabeçalho do DANFE NFC-e térmico,
  com reserva correspondente no cálculo do comprimento da bobina.
- O DANFE NFC-e térmico passou a gerar a segunda via do estabelecimento para
  contingência offline quando `offlineDoublePrint` está habilitado.
- O DANFE NFC-e térmico passou a exibir marca d'água discreta de homologação
  quando `environment=2`, mantendo a mensagem fiscal textual.
- DANFE A4 e NFC-e térmico passaram a identificar explicitamente documentos
  emitidos em homologação com `SEM VALOR FISCAL - HOMOLOGAÇÃO`.
- O conversor TXT passou a suportar as bases `LOCAL_V12` e `SEBRAE` do
  NFePHP 4.00, incluindo normalização de pagamentos `YA01`/`YA04`, troco,
  `cBenef` comercial e IPI devolvido `UA`/`UA03`, com fixture de regressão.
- Adicionado o alias `Tools.sefazConsultaGTIN()` com a capitalização original
  do NFePHP e um verificador executável da superfície pública de `Tools` na CI.
- `XsdValidator` passou a oferecer `validateContent()` com adaptador em
  memória para integrações Flutter/mobile, mantendo falha explícita quando
  nenhum parser XSD foi configurado.
- Corrigido o cancelamento por substituição para emitir os campos adicionais
  exigidos pelo NFePHP (`cOrgaoAutor`, `tpAutor`, `verAplic` e `chNFeRef`),
  com validação de modelo 65 e configuração de versão/modelo no `SefazClient`.
- O DANFE PDF A4 passou a apresentar o bloco fiscal detalhado de transportador,
  veículo, reboques, volumes, lacres e retenção de transporte; o bloco de
  informações adicionais também imprime observações identificadas, processos e
  autorizações de download do XML.
- O canhoto de recebimento do DANFE NF-e passou a ser renderizado no topo da
  primeira página, antes do cabeçalho fiscal, conforme a estrutura de impressão
  de referência do `sped-da`.
- Adicionada a ferramenta executável `tool/verify_nfephp_api.dart` e o job de
  CI que compara a superfície pública de `Make` com o NFePHP v5.0.100 fixado.
- Adicionado o probe `tool/verify_nfephp_make.dart`, que compara em runtime os
  grupos `infNFe` e `ide` produzidos pelo `Make` PHP e pelo builder Dart.
- Corrigida a fachada pública `taginfNFe()` para retornar somente o grupo
  `infNFe` com seus atributos, como no NFePHP; a montagem completa continua
  sendo responsabilidade de `build()`/`montaNFe()`.
- O TXT local 4.00 passou a aceitar o marcador oficial `B19` para referências
  de CT-e, mantendo `BA19` como alias retrocompatível.
- Adicionada verificação de inventário do layout TXT NFePHP na CI.
- O TXT passou a aceitar as cardinalidades legadas e estendidas dos registros
  `B` e `YA`, preservando os índices corretos de contingência, processo,
  versão e descrição de pagamento.

- O conversor TXT passou a preservar a descrição opcional `xPag` do registro
  `YA` nos pagamentos e o layout estrutural passou a exigir esse campo na
  posição oficial.
- O conversor TXT passou a respeitar `indIntermed` no registro `B`, corrigindo
  as posições de `procEmi`, `verProc`, `dhCont` e `xJust`, e passou a converter
  o cadastro do intermediador do registro `YB` para `infIntermed`.
- O campo opcional `dhSaiEnt` passou a ser modelado por
  `NfeDocument.departureDate`, convertido do cabeçalho TXT e preservado no
  XML e nos renderizadores DANFE.
- `DanfePdfOptions` passou a aceitar `fontBytes` para que a aplicação forneça
  uma fonte TTF/OTF licenciada e preserve Unicode completo no PDF auxiliar;
  fontes não são distribuídas pelo núcleo.
- DANFE HTML e PDF A4 passaram a exibir identificação da operação, indicadores
  fiscais, processo emissor, locais de retirada/entrega, referências e contexto
  de contingência, mantendo explícito o caráter auxiliar da diagramação.
- `DanfePdfOptions` passou a oferecer opções de apresentação do `sped-da` para
  largura/margem, via resumida, via estabelecimento, cancelamento, segunda via
  offline e conteúdo adicional.
- A composição da chave de acesso e a validação de `dhEmi` passaram a usar a
  mesma data UTC do XML, evitando divergências quando o instante informado
  atravessa mês ou ano por causa do fuso.
- Adicionada a fábrica `Contingency.forState()` com o roteamento SVC-AN/SVC-RS
  por UF compatível com a tabela do NFePHP.
- Adicionado `NfeTxtValidator` com a estrutura local 4.00 e suporte a layouts
  TXT fornecidos pela aplicação, cobrindo a validação estrutural do `ValidTXT`.
- Adicionado `NfeTxtConverter` para o subconjunto seguro de cabeçalho, emitente,
  destinatário, endereço e produtos, com rejeição explícita de registros ainda
  não mapeados.
- O conversor TXT passou a mapear também ICMS normal e PIS/COFINS por alíquota
  ou quantidade, mantendo rejeição explícita das variantes não suportadas.
- O conversor TXT passou a mapear imposto de importação, PIS-ST, COFINS-ST e
  ISSQN, mantendo as demais variantes legadas explicitamente rejeitadas.
- O conversor TXT passou a mapear também ICMS-ST (`N03`) com FCP próprio e
  FCP-ST.
- O conversor TXT passou a mapear ICMS com redução de base, desoneração,
  diferimento e ICMS-ST retido (`N04`, `N06`, `N07`, `N08`).
- `IcmsStTax` passou a preservar CST/origem e a emitir `ICMS90` quando
  aplicável; o conversor TXT também cobre `N09` e `N10`.
- O conversor TXT passou a mapear ICMS do Simples Nacional com crédito,
  substituição tributária e ICMS efetivo (`N10C`–`N10H`).
- `IcmsSimplesTax` passou a preservar FCP retido e ICMS efetivo do `ICMSSN500`,
  habilitando a conversão completa do registro TXT `N10G`.
- O conversor TXT passou a mapear IPI tributado e não tributado (`O07`, `O08`,
  `O10`) e IPI por unidade (`O11`) para `qUnid`/`vUnid`.
- O conversor TXT passou a mapear pagamentos (`YA`), cobrança/duplicatas
  (`Y02`/`Y07`), transporte (`X*`) e informações adicionais (`Z*`).
- O conversor TXT passou a mapear NVE, CEST, escala relevante e fabricante
  (`I05A`/`I05C`).
- PISOutr/COFINSOutr passaram a preservar no XML TXT suas variantes por base ou
  por quantidade (`Q07`/`Q10` e `S07`/`S09`).
- O registro TXT `M` passou a gerar `<vTotTrib>` por item, com validação de
  valores não negativos.
- O conversor TXT passou a mapear locais de retirada e entrega (`F`/`G`) com
  endereço e identificação CNPJ/CPF.
- O conversor TXT passou a mapear documentos referenciados `BA02`, `BA03`,
  `BA10`, `BA19` e `BA20` para os grupos `NFref` correspondentes.
- Destinatários estrangeiros do registro `E03A` passaram a ser convertidos
  para `idEstrangeiro`.
- O conversor TXT passou a mapear o grupo de medicamento `K` para `med`.
- O conversor TXT passou a mapear combustível, CIDE e encerrante (`LA`,
  `LA07` e `LA11`) para `comb`.
- O conversor TXT passou a mapear rastreabilidade de lote (`I80`) para
  `rastro`.
- O conversor TXT passou a mapear declarações e adições de importação
  (`I18`/`I25`) para `DI`/`adi` por item.
- O conversor TXT passou a mapear exportação individual (`I50`/`I52`) para
  `detExport`/`exportInd` por item.
- O conversor TXT passou a mapear veículo novo (`JA`) e armamento (`L`) para
  os grupos especiais correspondentes.
- O conversor TXT passou a mapear a partilha de ICMS para UF de destino
  (`NA`) para `ICMSUFDest`.
- Corrigida a emissão do grupo `<imposto>` quando o item contém apenas
  `ICMSUFDest`.
- O conversor TXT passou a mapear IPI devolvido (`UA`) para `impostoDevol`.
- O conversor TXT passou a mapear troco (`Y`) para `pag/vTroco`.
- O conversor TXT passou a mapear retenções federais (`W23`) para `retTrib`.
- `NfceQrCode.injectIntoXml()` passou a cobrir a injeção do suplemento NFC-e
  em XML já assinado, equivalente ao `Factories\\QRCode::putQRTag()`.
- O DANFE PDF A4 passou a oferecer canhoto de recebimento opcional, ativado
  por padrão para NF-e e controlado por `DanfePdfOptions.showReceiptStub`.
- O DANFE PDF A4 passou a exibir rodapé de paginação em continuações geradas
  pelo `MultiPage`.
- Adicionado `ContingencyXmlAdjuster` para adaptar XML legado a contingência,
  remover assinatura obsoleta e recalcular a chave antes de nova assinatura.

## Unreleased

- O conversor TXT passou a aceitar os nomes de locais de retirada/entrega
  (`F02B`/`G02B`) e os marcadores de agrupamento sem dados (`N`, `Q`, `S`).
- O conversor TXT passou a converter o registro `D` para o grupo `avulsa`,
  com o modelo público `AvulsaInfo` e validações fiscais básicas.
- `AccessKey`, `NfeDocument` e o conversor TXT passaram a aceitar emitente
  identificado por CPF (`C02A`), preenchendo a chave com 14 posições fiscais.
- Adicionado suporte ao total legado de ISSQN do TXT (`W17`), exposto como
  `ServiceTotal` e emitido em `ISSQNtot`.

- `IpiTax` e `NfeTxtConverter` agora suportam IPI por unidade (`O11`, `qUnid`/`vUnid`).
- Adicionado `IcmsStRetainedTax` para converter o registro `N10B`, preservando ICMS-ST retido, destino, FCP e valores efetivos.
- `IcmsStTax` agora suporta o grupo `ICMSST` sem operação própria (`N05`), incluindo FCP-ST e desoneração.
- `IcmsStTax` e `NfeTxtConverter` agora preservam `pBCOp`/`UFST` do registro `N10A` ao emitir `ICMS10`.
- `NfeTxtConverter` agora converte `ZD` para `infRespTec` (incluindo `idCSRT`/`hashCSRT`) e `ZX01` para `infNFeSupl` da NFC-e.
- `NfeTxtConverter` agora converte `ZA`/`ZB`/`ZC` e seus detalhes `ZC04`/`ZC10` para exportação, compra e aquisição de cana.
- `NfeTxtConverter` agora associa `BA13`/`BA14` a `BA10`, emitindo CNPJ/CPF em referências `refNFP` e rejeitando identificadores ambíguos.
- `NfeTxtConverter` agora converte autorizações `GA02`/`GA03` para `autXML` e o registro de item `LB` para `nRECOPI`.
- `NfeTxtConverter` agora converte os registros TXT `X22`, `X25A` e `X25B` para reboques, vagão ferroviário e balsa no XML de transporte.
- A compatibilidade de `Certificate` foi ampliada com `getICP()`,
  `getCAurl()`, `getCSP()`, representação PEM e `toString()` equivalente ao
  certificado público do NFePHP, além de verificação RSA com a chave pública
  X.509, verificação criptográfica do emissor/cadeia e assinatura/verificação
  textual na identidade PFX.
- Verificadores RSA SHA-1/SHA-256 passaram a tratar Base64 e assinaturas
  malformadas como rejeição (`false`), sem propagar exceções na fronteira de
  validação XMLDSig.
- `NfeXmlValidator` passou a aceitar um verificador XMLDSig opcional para
  confirmar criptograficamente o digest e o `SignatureValue` do documento.
- Adicionado `Certificate.writePfx()` para exportar identidades RSA PKCS#8 em
  PKCS#12 com PBE 3DES e MAC SHA-1, validado por round-trip e OpenSSL.
- Ampliados os grupos IBS/CBS com diferimento (`gDif`), devolução (`gDevTrib`)
  e redução (`gRed`) por competência, validados contra o PL_010f vigente.
- Adicionados contratos de saída `FiscalOutputAdapter`, callback para plugins,
  gravação em arquivo e envio TCP para impressoras de rede.
- Adicionado `EscPosEncoder` para converter DANFE textual em bytes ESC/POS,
  com sanitização de controle, alimentação, corte e encoder de página opcional.
- Adicionado o alias `Tools.sefazEPEC()` com a capitalização original da API
  NFePHP, mantendo `sefazEpec()` como forma idiomática Dart.
- Adicionado o evento de ator interessado `110150`, com autorização tipada de
  acesso ao XML, suporte a CNPJ/CPF e validação no schema oficial.
- Adicionado o ponto de entrada compatível `Certificate.readPfx()`, com os
  metadados da identidade delegados ao certificado carregado.
- Corrigida a leitura ASN.1 dos atributos RDN aninhados do `subject`/`issuer`,
  recuperando corretamente o `commonName` e os metadados de certificadora.
- O DANFE HTML agora embute o QR Code NFC-e como SVG autocontido, sem imagem
  externa ou dependência de driver de impressão.
- Corrigido o totalizador “Produtos” do DANFE HTML para usar `vProd` bruto,
  sem incorporar frete, seguro, outras despesas ou desconto do item.
- As colunas de total dos itens nos renderizadores DANFE PDF, HTML e textual
  agora exibem `vProd` bruto; os rateios permanecem separados nos totais.
- O DANFE NFC-e térmico passou a calcular o comprimento da bobina de 80 mm
  conforme a quantidade e o tamanho aproximado das descrições dos itens,
  reservando espaço para destinatário, contingência e QR Code.

- Adicionados `Make.setOnlyAscii()`, `Make.getErrors()` e `tagRECOPI()`
  para ampliar a compatibilidade tipada com o `Make` do NFePHP.

- Adicionados os aliases `Tools.sefazCadastro()` e `Tools.sefazManifesta()` e
  o envio de eventos genéricos por `Tools.sefazEvento()`.

- Portados os eventos de prorrogação e cancelamento de prorrogação de retorno
  (`sefazEPP`/`sefazECPP`, códigos `111500` a `111503`).

- Adicionada a administração tipada do CSC NFC-e por `Tools.sefazCsc()` com
  endpoint SOAP configurável e validação de contexto e dados.

- Adicionado `Tools.sefazEventoLote()` para combinar até 20 eventos, mantendo
  as assinaturas individuais antes do envio SOAP.

- Adicionados `Tools.sefazManifestaLote()` e `Tools.sefazValidate()` para
  manifestação tipada em lote e validação estrutural seguida de consulta por
  chave.

- Ampliados os metadados públicos de `Certificate` com empresa, validade,
  expiração e identificação opcional de CNPJ/CPF do `subject` X.509.

- Completa a fachada `Standardize` com `simpleXml()` e a propriedade pública
  `key`, preservando o resultado tipado em Dart.

- Adicionada referência de nota de produtor rural (`refNFP`/`tagrefNFP`) com
  suporte a CNPJ ou CPF, IE e validação dos campos fiscais.

- Corrigido `tagprod()` para retornar o grupo XML `<prod>` como no NFePHP;
  `tagdet()` permanece responsável pelo detalhe completo.

- Ampliada a fachada `Make` com os aliases de estado/documento (`monta`,
  `getXML`, `getChave`, `getModelo`) e com `tagdet`, `tagforDia`, `tagdeduc` e
  `taginfNFeSupl`, mantendo modelos Dart imutáveis.

- A validação GTIN passou a rejeitar entradas com letras ou separadores, mesmo
  quando os dígitos contidos formariam um código válido.

- O validador XML passou a exigir exatamente um documento por participante e a
  validar `indTot` e `vTroco` quando esses campos são informados.

- O builder passou a rejeitar números de item duplicados e valores `NaN`/infinito
  antes de gerar XML fiscal.

- Falhas de DNS, conexão e outros `IOException` do transporte SEFAZ agora são
  normalizadas como `SEFAZ_NETWORK_ERROR` e preservam documentos offline em
  estado `unknown`, sem reenvio automático.

- Configuração de `SOAPAction` específica por operação no cliente SEFAZ, com
  fallback compatível para a ação global.

- Reforçada a validação de bases e alíquotas dos grupos IBS/CBS e Imposto
  Seletivo, rejeitando valores negativos ou percentuais fora de 0 a 100.

- Adicionado o evento de cancelamento por substituição (`110112`) com as
  validações de protocolo, justificativa e identificação do emitente.

- Integrado o cancelamento por substituição à fachada `Tools`, incluindo
  assinatura opcional e envio SOAP pelo cliente SEFAZ.

- O parser de respostas agora identifica `soap:Fault` e retorna a exceção
  fiscal estável `SEFAZ_SOAP_FAULT`, preservando código e motivo legíveis.

- `serviceVersion` da configuração SEFAZ passou a ser propagado aos envelopes
  NF-e de status, consulta, recibo e autorização, mantendo `4.00` como padrão.

- Falhas `SEFAZ_SOAP_FAULT` na transmissão offline agora preservam o documento
  em estado `unknown`, exigindo consulta explícita antes de qualquer reenvio.

- Mapas de endpoints e `SOAPAction` do cliente SEFAZ passaram a ser cópias
  defensivas imutáveis após a criação da configuração.

- `SefazRetryPolicy` passou a congelar os códigos HTTP transitórios por cópia
  defensiva, evitando alteração de política durante uma transmissão.

- Adicionado o evento de comprovante de entrega da NF-e (`110130`), com hash
  SHA-1 em Base64, recebedor, data, GPS opcional e integração à fachada `Tools`.

- Adicionada a matriz `PLATFORM_SUPPORT.md`, distinguindo evidência de CI,
  builds Flutter e limitações que dependem de dispositivos ou credenciais.

- Documentada em `ARCHITECTURE.md` a decisão de manter o núcleo Dart/Flutter em
  um pacote único com adaptadores injetáveis por plataforma.

- Adicionado `gCompraGov`/`taggCompraGov()` com `GovernmentPurchase`,
  referências `refDFeAnt` e validação das regras por tipo de operação.

- Adicionado `gPagAntecipado`/`taggPagAntecipado`, com referências de NF-e de
  pagamento antecipado e validação de até 99 chaves no grupo `ide`.

- Adicionado o grupo `infIntermed` com `IntermediaryInfo`, integração ao
  documento e fachada `Make.taginfIntermed()`, incluindo a regra de coerência
  com `indIntermed=1`.

- Adicionadas consulta pública de GTIN (`consGTIN`) e solicitação de download
  de NF-e (`downloadNFe`), com validação de Mod-10, CNPJ, chaves e limite de
  dez documentos por requisição.

- Adicionadas as operações SEFAZ de distribuição de DF-e (`distDFeInt`) e
  consulta cadastral (`consCad`), com filtros validados, CPF/CNPJ/IE,
  roteamento por endpoint e fachadas `Tools`.

- Adicionada fixture assinada de extensões tributárias com validação real no
  XSD PL_010f, cobrindo `II`, PIS/COFINS-ST, partilha, RTC, devolução e
  retenções federais.

- Adicionados `impostoDevol` e `retTrib`, com modelo de IPI devolvido por item,
  totalização de `vIPIDevol` e retenções federais no total da NF-e.

- Adicionadas fachadas agregadoras para `ICMSTot`, `ISSQNtot`, `detPag`,
  `fat` e `dup`, com validação de ausência de total de serviço.

- Ampliadas as fachadas de compatibilidade com referências `NFref` e com o
  encerrante de combustível (`tagrefNFe`, `tagrefNFeSig`, `tagrefCTe`,
  `tagrefNF` e `tagencerrante`).

- Adicionados os locais fiscais tipados `retirada` e `entrega`, com endereço,
  telefone, e-mail, IE e validação de CPF/CNPJ.

- Expandido `AdditionalInfo` com `obsCont`, `obsFisco`, `procRef` e `autXML`,
  incluindo validação de identificadores e emissão direta de `autXML` em
  `infNFe`.

- Adicionados os grupos tipados `II`, `PISST` e `COFINSST`, incluindo as
  variantes por percentual e por quantidade de PIS/COFINS-ST.

- Adicionados os grupos tipados `ICMSPart` e `ICMSUFDest`, com emissão na
  ordem do leiaute PL_010f e totalização de FCP/ICMS por UF.

- Expostas na fachada `Make` as tags tipadas de produto, importação e
  exportação (`tagNVE`, `tagCEST`, `taginfAdProd`, `tagDI`, `tagadi`,
  `tagdetExport` e `tagdetExportInd`), com cobertura de regressão.

- Incorporado o pacote oficial vigente `PL_010f_v1.04`, com manifesto de
  hashes, validação dos cinco XSDs e fixtures fiscais validadas contra o novo
  `nfe_v4.00.xsd`; PL_010b permanece para regressão histórica.
- Adicionada a ferramenta `verify_schema_manifest.dart` e sua execução na CI
  para detectar alterações ou corrupção nos XSDs versionados.
- Adicionados os campos RTC de crédito presumido `gCred` e
  `tpCredPresIBSZFM`, validados contra o PL_010f.
- Adicionados campos comerciais do PL_010f (`cBarra`, `cBarraTrib`,
  `indEscala` e `CNPJFab`), incluindo a regra de dependência do CEST.
- Adicionado `IcmsTax.benefitReductionCode` para emissão de `cBenefRBC` nos
  grupos ICMS51/ICMS90 do PL_010f.
- Adicionado `NfeItem.recopiNumber` para emissão do registro `nRECOPI` do
  PL_010f.

- O transporte mTLS passou a encaminhar todos os certificados X.509 presentes
  no PFX, incluindo intermediárias, sem alterar a política de raízes confiáveis
  do runtime.

- Ampliada a fachada `Make` com grupos tipados de totalização, pagamentos,
  transporte, cobrança, informações adicionais, responsável técnico,
  exportação, compra e aquisição de cana.

- Adicionado `NfeAuthorization` para transportar protocolo, situação, motivo e
  data de autorização até os renderizadores DANFE PDF/HTML.

- Adicionados os grupos de produto `veicProd` e `arma`, com modelos tipados,
  validação de campos do schema e regra de escolha exclusiva com `med`/`comb`.
- O transporte agora suporta dados completos do transportador, RNTC, reboques,
  vagão, balsa, volumes e lacres, com fixture comercial validada no XSD PL_010b.
- Adicionada a retenção de ICMS do transporte (`retTransp`) com validação de
  CFOP, município, alíquota e valores.
- Materiais DER e PKCS#8 expostos pela API de certificados agora usam cópias
  defensivas, evitando mutação acidental do estado interno de assinatura/mTLS.
- Os renderizadores DANFE PDF/HTML passaram a exibir cobrança, duplicatas,
  informações adicionais, totais de PIS/COFINS/ISSQN e detalhes de transporte.
- Adicionado fixture assinado de reforma tributária com IBS/CBS/IS, validado
  contra o XSD PL_010b; corrigida a ordem `IS`/`IBSCBS` no grupo `imposto`.
- O exemplo Flutter passou a incluir scaffolds Android/iOS, teste de widget e
  validação local de APK debug e build iOS sem assinatura.
- Adicionados os grupos de documento `exporta`, `compra` e `cana`, incluindo
  fornecimentos diários e deduções de aquisição de cana.
- Adicionado o fixture `validate_product_specials.dart`, assinado e validado
  pelo XSD PL_010b para cobrir `veicProd` e `arma` na CI.
- Adicionados `FuelInfo`, `FuelCide` e `FuelGauge` para combustíveis ANP,
  CIDE e encerrante, com validação da escolha exclusiva de grupos especiais.
- Adicionados `ProductTraceability` e `MedicationInfo` para os grupos
  `rastro` e `med`, com fixture assinada validada pelo schema oficial.
- Adicionados `ImportDeclaration` e `ImportAddition` para os grupos `DI`/`adi`
  de comércio exterior em itens de NF-e, além de `ExportDetail` e
  `IndividualExport` para `detExport/exportInd`.
- `NfeItem` passou a suportar metadados comerciais e fiscais opcionais:
  `NVE`, `CEST`, `cBenef`, `EXTIPI`, pedido de compra e `infAdProd`.
- A CI do exemplo Flutter passou a executar análise, testes e bundle em
  Linux, macOS e Windows.
- Operações SOAP fiscais passaram a usar o wrapper `nfeDadosMsg` exigido pelo
  transporte NFePHP; o modo GZIP continua usando `nfeDadosMsgZip`.
- `sefazEnviaLote()` passou a suportar compactação GZIP opt-in compatível com
  `nfeDadosMsgZip` do NFePHP.
- O cliente SEFAZ passou a aceitar endpoints HTTPS distintos por operação
  (`SefazOperation`), mantendo fallback compatível para um endpoint único.
- O adapter Drift do exemplo passou a persistir `deadlineAt` no schema 3 e a
  marcar documentos expirados durante a reivindicação atômica da fila.
- Assinatura XML e transporte mTLS agora rejeitam certificados A1 fora da
  validade temporal X.509.
- `NfeXmlValidator.assertValid()` passou a aceitar `requireSignature`,
  mantendo a mesma proteção estrutural disponível em `validate()`.
- `NfeEmissionService.authorize()` agora bloqueia explicitamente NFC-e offline;
  esses documentos devem seguir pela fila e transmissão posterior.
- A fila offline passou a reconhecer `AtomicFiscalDocumentStore` para que
  adapters persistentes reivindiquem documentos dentro de transações.
- Atualizado o README em português com a API pública atual, criação de chave
  por componentes e limitações de homologação/XSD/DANFE.

- Adicionadas manifestações do destinatário (ciência, confirmação,
  desconhecimento e operação não realizada), com suporte a CPF/CNPJ e envio
  pela fachada `Tools`.
- Adicionado o evento EPEC (`110140`) com validação de `tpEmis=4`, autor,
  destinatário opcional, valores fiscais e versão do aplicativo.
- A assinatura XMLDSig passou a aceitar eventos `envEvento`, mantendo a
  assinatura dentro de `evento/infEvento` e a verificação contra wrapping.
- Eventos passaram a emitir datas UTC no formato fiscal sem milissegundos e o
  EPEC valida o limite oficial de 20 caracteres para `verAplic`.
- `Tools` passou a aceitar `XmlSignatureService` opcional e assinar
  automaticamente cancelamento, CC-e, manifestações e EPEC antes do envio.
- A inutilização também passou a ser assinada automaticamente pela fachada
  `Tools` quando há certificado configurado.
- Adicionada `SefazClientConfig` com configuração validada de UF, ambiente,
  modelo, versão do serviço, endpoint, timeout, SOAP action e certificado A1.
- Corrigida a formação do `Id` de `infInut` para o padrão oficial de 41
  dígitos; a inutilização assinada agora passa pelo schema PL_009_V4.
- Adicionada `SefazRetryPolicy`, com repetição opt-in de respostas HTTP
  transitórias e sem repetição automática de timeouts fiscais.
- Adicionada a fábrica `NfeDocument.fromComponents()`, que calcula a chave de
  acesso oficial e deriva `tpEmis` da contingência configurada.
- Adicionado o contrato `FiscalNumberAllocator` e alocador em memória para
  testes, deixando explícita a necessidade de transação persistente ou
  coordenação externa entre caixas em produção.
- O exemplo Flutter passou a incluir `DriftFiscalNumberAllocator`, com reserva
  transacional de numeração em SQLite e migração do schema para a versão 2.
- Atualizado `README_EN.md` para refletir a API implementada e as limitações
  ainda não comprovadas por homologação real.

- Adicionados os grupos ICMS20, ICMS40/41/50, ICMS51, ICMS60 e ICMS90, com
  validação de CST, origem, desoneração, diferimento e ST retido; o CI valida
  esses grupos contra o schema PL_010b.
- Adicionados os grupos do Simples Nacional `ICMSSN101`, `102`, `201`, `202`,
  `500` e `900`, com validação de créditos, ST e retenções.
- Adicionados os grupos monofásicos `ICMS02`, `ICMS15`, `ICMS53` e `ICMS61`,
  com totalizadores de quantidade, valor próprio e retenção.
- IPI passou a selecionar corretamente `IPITrib` ou `IPINT` para CSTs
  tributados e não tributados.
- `Make` e `NfeXmlBuilder` passaram a expor fachadas tipadas para `taginfNFe`,
  `tagide`, `tagemit`, `tagdest`, `tagprod` e `tagimposto`.
- `NfeEmissionService.authorize()` passou a encadear assinatura, envio de lote
  via `SefazClient` e normalização do retorno SEFAZ.
- DANFE PDF A4 passou a discriminar emitente, destinatário, NCM/CFOP, totais
  fiscais, transporte e pagamentos, mantendo o QR Code da NFC-e.
- DANFE HTML passou a discriminar emitente, destinatário, NCM/CFOP, totais
  fiscais, transporte e pagamentos, mantendo o escape de conteúdo e o QR Code.
- A fila de contingência NFC-e passou a aceitar prazo operacional de transmissão
  e a marcar documentos vencidos como `expired`, sem reivindicá-los para envio.
- Adicionado coordenador de transmissão posterior que persiste retornos SEFAZ,
  evita reenvio após estado desconhecido e permite resolução por consulta.
- Retornos de rejeição fiscal 5xx, como `539`, passaram a ser classificados
  corretamente como rejeitados.
- `Certificate` passou a expor `notBefore`, `notAfter` e `isValidAt()` para
  verificar a validade temporal X.509 de certificados PEM/PFX.
- `Certificate` e `PfxIdentity` passaram a oferecer leitura assíncrona de
  PFX/P12 diretamente por caminho de arquivo.
- O parser SEFAZ passou a priorizar o `cStat` do protocolo interno em lotes
  processados (`104`), reconhecendo autorização ou rejeição efetiva do documento.
- `NfeXmlValidator` passou a calcular `vNF` com `FiscalDecimal`, considerando
  frete, seguro, desconto, II, IPI, ICMS-ST e outras despesas, além de rejeitar
  totalizadores com formato decimal inválido.
- A validação estrutural de pagamentos passou a considerar `vTroco` no fechamento
  contra `vNF` e a rejeitar `vPag` com formato inválido.
- `SefazResult` passou a distinguir operações aceitas, autorização de eventos
  (`135/136/155`) e inutilização homologada (`102`) da autorização de NF-e.
- Os totalizadores XML passaram a respeitar `NfeItem.includeInTotal`, mantendo
  itens `indTot=0` no documento sem incluí-los nos valores fiscais.
- Os totais discriminados dos renderizadores DANFE HTML e PDF passaram a
  respeitar a mesma regra `indTot`.
- O validador XML passou a respeitar `indTot=0` ao conferir a soma dos itens.
- O validador XML passou a validar CNPJ/CPF e `xNome` do destinatário quando o
  grupo `dest` é informado.
- A fachada `Tools` passou a declarar explicitamente o parâmetro público
  obrigatório `sefaz`, sem estado anulável interno.
- O validador XML passou a exigir `dhCont`/`xJust` para `tpEmis=9` e a rejeitar
  contingência offline aplicada indevidamente ao modelo 55.

## 0.1.0

- Estrutura inicial da FlutterFiscalLIB.
- Modelos de documento, participante e item.
- Geração XML estrutural para NF-e/NFC-e.
- Validações básicas e testes automatizados.
- Validação semântica do XML para coerência da chave, `ide`, emitente, itens,
  totalizadores e pagamentos.
- Suporte tipado a documentos referenciados, cobrança com fatura/duplicatas e
  responsável técnico no XML.
- Coerência obrigatória entre campos da NF-e/NFC-e e a chave de acesso, além
  de normalização e validação de transportador, placa e UF.
- Campos de unidade tributável, quantidade tributável, preço tributável, GTIN
  tributável e indicador de composição do total no grupo `prod`.
- Campos de identificação e indicadores da operação no grupo `ide`, incluindo
  `cNF`/`cDV` derivados da chave.
- Formatação fiscal de data/hora com offset e campos adicionais do processo,
  endereço do emitente e totalizadores ICMS exigidos pelo leiaute.
- Fachada `NfeEmissionService` para montar, assinar e verificar documentos sem
  confundir XML estrutural com XML pronto para transmissão.
- Suplemento NFC-e `infNFeSupl` para transportar QR Code e URL da chave quando
  fornecidos pela aplicação.
- CI passou a verificar também o exemplo Dart com o SDK mínimo declarado.
- O perfil fiscal XMLDSig passou a usar SHA-1 e duas transformações conforme o
  schema PL_010b, com SHA-256 mantido como opção explícita.
- `SefazClient` passou a expor consulta de protocolo, envio de eventos e
  inutilização com validação das raízes XML.
- Renderizadores DANFE textual, HTML e PDF passaram a incluir QR Code/URL da
  chave quando o suplemento NFC-e está presente.
- O DANFE PDF NFC-e também renderiza o conteúdo do QR Code como gráfico
  escaneável usando o widget barcode do pacote `pdf`.
- Pagamentos suportam integração eletrônica, bandeira, autorização, descrição
  e troco (`vTroco`).
- IPI tributado (`IPITrib`) passou a ser suportado por item e totalizado em
  `ICMSTot/vIPI`.
- ICMS-ST (`ICMS10`) e FCP próprio/FCP-ST passaram a ser suportados com seus
  respectivos totalizadores.
- `SefazClient` passou a aceitar timeout configurável e a sinalizar respostas
  não determinísticas com `SEFAZ_TIMEOUT`, evitando reenvio automático inseguro.
- Itens passaram a suportar rateios de frete, seguro, desconto, outras despesas
  e imposto de importação, com totalização fiscal de `vNF`.
- PIS e COFINS passaram a selecionar os grupos `*Aliq`, `*NT` ou `*Outr`
  conforme o CST informado.
- PIS e COFINS com CST 03 passaram a emitir `PISQtde`/`COFINSQtde`, com
  quantidade, alíquota por unidade e validação XSD.
- O renderizador PDF passou a oferecer layout NFC-e térmico de 80 mm com QR
  Code, chave, pagamentos e identificação de contingência.
- Foi adicionada uma fixture executada contra `NFePHP/sped-nfe` `v5.0.100`
  para regressão normalizada da operação `tagide()`.
- `Tools` passou a oferecer uma fachada tipada para as operações SEFAZ
  equivalentes a lote, recibo, consulta de chave, status e inutilização.
- A fachada `Tools` também passou a gerar e enviar eventos de cancelamento e
  Carta de Correção (`sefazCancela`/`sefazCCe`).
- Adicionado suporte tipado a serviços com `ISSQN` e totalizador `ISSQNtot`.
- O cenário assinado de validação agora comprova `ISSQN` contra o XSD PL_010b;
  campos opcionais de ISSQN zerados não são emitidos.
- Adicionada `NfceOfflineEmissionService`, que coordena assinatura, digest,
  QR Code offline 2.00 e suplemento NFC-e antes da persistência na fila.
- `Complements.cancelRegister()` foi alinhado ao NFePHP: o protocolo passa a
  `cStat=101` com o novo número de protocolo e motivo de cancelamento.
- Foi adicionada fixture real de `toAuthorize()` gerada pelo NFePHP para
  regressão estrutural normalizada.
- `Complements.b2bTag()` passou a criar o envelope `nfeProcB2B` com tag B2B
  configurável.
- `Complements.toAuthorize()` passou a protocolizar também eventos e
  inutilizações, com validação de lote, status e campos correspondentes.

- Adicionados scaffolds Flutter para Linux, macOS e Windows, com builds
  condicionais desses alvos no CI e instruções de validação no exemplo.

- Adicionados `FuelInfo.biofuelPercentage` e `FuelInfo.origins`/`FuelOrigin` para
  emitir `pBio` e `origComb` do PL_010f, com validação de percentual, UF e
  limite de 30 origens; a fixture de comércio foi validada contra o XSD vigente.

- Adicionados `indIntermed` e `cIndOp` ao `NfeDocument`, com validação e
  emissão na ordem do grupo `ide` do PL_010f; `procEmi=4` também passou a ser
  aceito conforme o leiaute vigente.

- Ampliada a identificação de `Party` com os campos de endereço e
  participante previstos no PL_010f (`xCpl`, `fone`, `xFant`, `IEST`, `IM`,
  `CNAE`, SUFRAMA, `indIEDest`, `idEstrangeiro` e `email`), incluindo
  validações de formato e fixture XSD.

- O DANFE PDF A4 e a NFC-e térmica passaram a renderizar o código de barras
  Code 128 da chave de acesso, além do texto da chave e do QR Code quando
  aplicável.

- Adicionado `XsdValidator`, adaptador explícito para validação contra XSD
  oficial via `xmllint` em desktop/CI, com executor injetável para adaptadores
  nativos e testes sem dependência de processo no núcleo fiscal.

- Expostos `tagenderEmit()` e `tagenderDest()` em `NfeXmlBuilder` e `Make`,
  alinhando a fachada com os métodos públicos do NFePHP `Make`.

- `ReferencedDocument` passou a suportar `refNFeSig` e `refCTe`, com
  validação de chave e emissão na escolha correta do grupo `ide/NFref`.

- Expostos na fachada `Make` os grupos de produto `tagRastro()`,
  `tagveicProd()`, `tagmed()`, `tagarma()` e `tagcomb()`, alinhados aos
  métodos públicos correspondentes do NFePHP.

- Expostos métodos tributários específicos compatíveis com o NFePHP:
  `tagICMS()`, `tagIPI()`, `tagPIS()`, `tagCOFINS()` e `tagISSQN()`.

- Adicionadas as fachadas tributárias `tagICMSSN()` e `tagICMSMono()` para
  CSOSN e ICMS monofásico.

- Expostos os subgrupos de transporte `tagveicTransp()`, `tagreboque()`,
  `tagvol()`, `tagvagao()` e `tagbalsa()` em `Make` e `NfeXmlBuilder`.

- Expostos também `tagtransporta()`, `tagretTransp()` e `taglacres()` para
  completar a montagem incremental dos subgrupos de transporte.

- Adicionada a fachada `tagICMSST()` para o grupo `ICMS10`, reutilizada pelo
  XML completo do item.

- Adicionada referência de cupom fiscal ECF (`refECF`/`tagrefECF`) com
  numeração formatada e validação estrutural.
