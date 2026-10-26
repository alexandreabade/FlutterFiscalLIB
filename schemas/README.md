# Schemas fiscais

O pacote de referência `PL_009_V4` está incorporado em `schemas/PL_009_V4`.
Sua origem, commit e hashes estão registrados em
`PL_009_V4.MANIFEST.json`. Ele corresponde à referência NFePHP fixada no
relatório técnico e deve ser escolhido conscientemente conforme o Pacote de
Liberação vigente no ambiente fiscal.

A API principal continua fazendo validação estrutural em Dart. A validação XSD
completa pode ser executada no desenvolvimento/CI com:

```bash
dart run tool/validate_xsd.dart \
  --schema schemas/PL_009_V4/nfe_v4.00.xsd \
  --xml caminho/para/documento.xml
```

Esse comando usa `xmllint`, portanto é uma ferramenta de validação externa e
não uma dependência runtime do núcleo Flutter multiplataforma.

Cada pacote redistribuído deve manter origem, versão, checksum, licença/termo
de uso e nota técnica correspondente no seu manifesto. O código da biblioteca
é MIT, mas essa licença não substitui os termos aplicáveis aos schemas
incorporados.

| Pacote | Referência fiscal | Licença/termo registrado |
| --- | --- | --- |
| `PL_009_V4` | leiaute NF-e 4.00 usado pelo `sped-nfe v5.0.100` | `LGPL-3.0-or-later`, conforme o manifesto |
| `PL_010b_NT2025_002_v1.30` | NT 2025.002-RTC, versão histórica | schema oficial disponibilizado pelo Portal Nacional da NF-e |
| `PL_010f_v1.04` | pacote oficial vigente incorporado, NT 2025.002 v.1.50/NT 2026.007 v.1.00 | schema oficial disponibilizado pelo Portal Nacional da NF-e; revisões posteriores são rastreadas em `REFERENCES.md` e ainda não são alegadas como incorporadas |

Os pacotes oficiais do Portal não são apresentados como código sob a licença
MIT deste projeto; a redistribuição deve respeitar as condições publicadas
pelo Portal Nacional da NF-e. A referência inicial do port é o
`sped-nfe v5.0.100` (`cf0baf0`), registrado em `REFERENCE_ANALYSIS.md`.

## NT 2025.002-RTC

O pacote histórico `PL_010b_NT2025_002_v1.30` está em
`schemas/PL_010b_NT2025_002_v1.30`. Ele contém os leiautes com os grupos
IBS/CBS/IS e seu manifesto registra a origem, data e hashes. Valide um XML
contra este pacote com:

```bash
dart run tool/validate_xsd.dart \
  --schema schemas/PL_010b_NT2025_002_v1.30/nfe_v4.00.xsd \
  --xml caminho/para/documento.xml
```

O pacote oficial vigente incorporado é `PL_010f_v1.04`, obtido do Portal
Nacional em 25/10/2026, com manifesto e hashes em
`PL_010f_v1.04.MANIFEST.json`. Valide um XML contra ele com:

```bash
dart run tool/validate_xsd.dart \
  --schema schemas/PL_010f_v1.04/nfe_v4.00.xsd \
  --xml caminho/para/documento.xml
```

Confira também a integridade dos arquivos antes da validação:

```bash
dart run tool/verify_schema_manifest.dart \
  --manifest schemas/PL_010f_v1.04.MANIFEST.json \
  --directory schemas/PL_010f_v1.04
```

O PL_009_V4 e o PL_010b permanecem disponíveis para regressão das referências
anteriores.

Para manifests no formato agregado (`file_count` e `aggregate_sha256`), o
checksum é calculado sobre as linhas `sha256  caminho`, ordenadas de forma
determinística pelo caminho relativo. O cálculo é feito inteiramente em Dart,
sem depender de executáveis externos.

