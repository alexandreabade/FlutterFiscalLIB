# Análise inicial das referências NFePHP

Consulta registrada em 25/10/2026. Este documento identifica fontes e não
declara que o port Dart esteja completo.

## Versões de referência

| Projeto | Escopo observado | Referência fixada |
| --- | --- | --- |
| `nfephp-org/sped-nfe` | Geração, assinatura e comunicação de NF-e/NFC-e | release `v5.0.100`, commit `cf0baf005691c3a9e252314150c7dac18adbb2ee` |
| `nfephp-org/sped-common` | Classes comuns para NFe, CTe e MDFe | snapshot `master` de 25/10/2026, commit `39ca47cce3b2b750e305cd84b7d98f3d670f6504` |
| `nfephp-org/sped-da` | Documentos auxiliares e DANFE | snapshot `master` de 25/10/2026, commit `308abfe0fe01a3a2c9acfc7b57bf59fcffc77717` |
| `nfephp-org/sped-gtin` | Validação de GTIN | snapshot `master` de 25/10/2026, commit `4ca4d57d9f57431b6c042b5a04266dffb7044575` |

## Observações de compatibilidade

- `sped-nfe` expõe `Make` e concentra a montagem de grupos XML, assinatura e comunicação com autorizadores.
- `sped-common` deve ser tratado como fonte de utilitários e contratos comuns, não como dependência de runtime Dart.
- `sped-da` separa documentos auxiliares do XML fiscal; a FlutterFiscalLIB mantém o renderizador textual como etapa intermediária e ainda não o considera DANFE PDF oficial.
- A superfície pública de `Danfe`/`Danfce` e os mapeamentos de opções estão
  detalhados em `DANFE_COMPATIBILITY.md`, incluindo a diferença de fonte por
  bytes e a opção de separadores tracejados dos itens.
- A implementação A4 foi conferida contra a referência `sped-da` fixada acima:
  o renderer Dart agora expõe os blocos de transportador/volumes/retenção e
  as observações identificadas do `infAdic`, segue a ordem visual da NT
  2026.010 (cobrança, totais, RTC, ISSQN, transporte e produtos) e identifica
  o quadro oficial de produtos/serviços, mas a paginação e a geometria ainda
  não são uma reprodução byte a byte do layout oficial.
- `sped-gtin` destaca que GTIN existente precisa ser informado e validado conforme as regras aplicáveis; `NfeXmlBuilder` aplica validação Mod-10 a `ean` e `eanTrib`, enquanto a consulta ao Cadastro Nacional de Produtos permanece fora do núcleo.

## Evidência dos snapshots

Os commits acima foram obtidos com `git ls-remote` nos repositórios oficiais em
25/10/2026. Como `master` é mutável, a data e o hash completo são parte da
referência; nenhum código PHP ou dependência de runtime é baixado pelo pacote.

## Inventário reproduzível da superfície pública

Os snapshots foram clonados em 25/10/2026 em diretório temporário e a
superfície pública foi comparada com os wrappers Dart. O comando de auditoria
foi equivalente a:

```sh
rg -o 'public function [A-Za-z0-9_]+' sped-nfe/src/Make.php
rg -o 'public function [A-Za-z0-9_]+' sped-nfe/src/Tools.php
rg -n '^  .*\(' lib/src/make.dart lib/src/xml/nfe_xml_builder.dart lib/src/tools.dart
```

No `Make` v5.0.100 foram encontrados 77 métodos públicos operacionais (78
incluindo o construtor), incluindo
`taginfNFe`, `tagide`, `tagrefNFe`, `tagrefNF`, `tagrefNFP`, `tagrefCTe`,
`tagrefECF`, `tagemit`, `tagdest`, `tagretirada`, `tagentrega`, `tagprod`,
`tagimposto`, todas as fachadas tributárias, transporte, cobrança, informações
adicionais, exportação, compra, cana, `taginfNFeSupl`, `montaNFe`, `monta`,
`getXML`, `getChave`, `getModelo`, `setOnlyAscii` e `getErrors`. A comparação
de nomes encontrou apenas `__construct` como diferença, pois o construtor PHP
é representado por construtores tipados e privados diferentes em Dart. Os
métodos Dart correspondentes estão em `Make` e `NfeXmlBuilder`; os parâmetros
foram convertidos de `stdClass` para modelos imutáveis e essa divergência está
registrada em `API_COMPATIBILITY.md`.

No `Tools` v5.0.100 foram encontrados 20 métodos públicos operacionais,
incluindo lote, recibo, consulta por chave, inutilização, cadastro, status,
distribuição DF-e, CC-e, prorrogação/cancelamento de prorrogação, cancelamento
normal/substituição, manifestação simples/lote, evento/lote, EPEC, download,
CSC e validação. Todos os nomes operacionais possuem correspondente em
`Tools`; as assinaturas Dart recebem `SefazClient` injetável, modelos tipados e
`Future<SefazResponse>`, em vez de estado/configuração global PHP.

O `sped-da` possui classes de DANFE muito maiores e com desenho PDF específico
(`NFe/Danfe.php` e `NFe/Danfce.php`, incluindo canhoto, marca d'água,
configurações de papel/fonte/margem, páginas de continuação e layout oficial).
`DanfePdfRenderer` e `DanfeHtmlRenderer` cobrem atualmente a representação
auxiliar multiplataforma, itens, tributos totalizados, operação, contingência,
transporte, cobrança, pagamentos, informações adicionais e QR Code, mas ainda
não são equivalentes ao layout oficial completo do `sped-da`. Essa diferença é
intencionalmente mantida como pendência explícita na matriz de compatibilidade.

## Próximas ações de rastreabilidade

1. Associar cada módulo Dart ao arquivo/classe PHP correspondente no commit
   fixado, preservando a licença aplicável.
2. Copiar para a matriz de compatibilidade a assinatura real de cada método público, com arquivo e teste.
3. Associar cada grupo XML a schema/nota técnica oficial e a uma fixture de regressão.

O registro de licença por componente dos schemas incorporados foi concluído:
consulte `REFERENCES.md`, `schemas/README.md` e os três manifestos JSON. A
lista acima permanece apenas para rastreabilidade detalhada de módulos e
grupos que ainda possam ser ampliados em versões futuras.

### Verificação executável da superfície `Make`

O arquivo `tool/verify_nfephp_api.dart` compara por expressão regular os
métodos `public function` de `src/Make.php` com os métodos públicos da fachada
`lib/src/make.dart`. A CI executa essa verificação contra a tag fixa
`v5.0.100`, além da suíte Dart. Métodos Dart adicionais são reportados, mas
não são tratados como equivalentes silenciosos; qualquer método público
NFePHP ausente faz a etapa falhar.

O arquivo `tool/verify_nfephp_make.dart` executa o `Make` PHP com Composer e
compara a estrutura produzida por `taginfNFe()`, `tagide()`, `tagemit()`,
`tagdest()`, `tagprod()` e `tagimposto()` com o `NfeXmlBuilder`. A comparação
usa nomes, atributos e valores dos nós; datas são comparadas como instantes
UTC e não por igualdade textual do fuso. Campos vazios, `SEM GTIN`, defaults
tributáveis derivados e a substituição de `xNome` em homologação são
normalizados como diferenças de representação entre a referência PHP e a API
tipada Dart, sem ocultar divergências nos valores fiscais comuns.

O arquivo `tool/verify_nfephp_tools_api.dart` compara a superfície pública de
`Tools.php` com `lib/src/tools.dart`. A CI executa essa verificação e mantém
aliases de capitalização como `sefazConsultaGTIN()`.

O arquivo `tool/verify_nfephp_surfaces.dart` compara adicionalmente as
superfícies públicas de `Complements`, `Standardize` e `Certificate` (incluindo
a normalização de `__toString` para `toString`). A CI executa essa verificação
contra os arquivos do commit fixado e reporta métodos Dart adicionais sem
tratá-los como equivalentes silenciosos.

O arquivo `tool/verify_nfephp_txt_layout.dart` compara o inventário de
marcadores do `docs/txtlayout400.md` com o mapa `NfeTxtLayout.local400()`;
`B19` é verificado explicitamente, com `BA19` preservado somente como alias
retrocompatível.

## Reforma Tributária do Consumo

O modelo inicial de `IbsCbsTax` e `SelectiveTax` segue a estrutura publicada na
[NT 2025.002-RTC](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=DaB0yzqdbRU%3D),
incluindo `IBSCBS`, `gIBSCBS`, `gIBSUF`, `gIBSMun`, `gCBS`, `ISTot` e
`IBSCBSTot`. As alíquotas não são fixadas pela biblioteca: são entradas da
aplicação e os valores são derivados com decimal exato. O schema
`PL_009_V4` mantido neste repositório é anterior à reforma e não é usado como
prova de validação XSD desses grupos. O pacote histórico
`PL_010b_NT2025_002_v1.30` foi incorporado e cobre a estrutura inicial da
reforma, mas está classificado como versão anterior no Portal Nacional. Em
26/10/2026, o Portal lista o pacote oficial em uso `PL_010f` (NT 2025.002
v.1.50 e NT 2026.007 v.1.00), além de revisões posteriores da NT 2025.002 e
novas notas técnicas de implantação. O pacote `PL_010f_v1.04`
foi incorporado com hash do arquivo ZIP, hashes individuais e validação dos
XSDs; o acesso exige o cookie `AspxAutoDetectCookieSupport=1`.

