# Homologação SEFAZ

Este documento descreve a execução opt-in contra um ambiente oficial de
homologação. A suíte não é executada automaticamente e nunca usa produção.

## Pré-requisitos

São necessários:

- certificado A1 de teste (`.pfx` ou `.p12`) válido para o ambiente;
- senha do certificado, fornecida somente por variável de ambiente;
- endpoint HTTPS oficial da UF e do modelo usado;
- código da UF (`cUF`) e sigla numérica da UF;
- autorização do responsável fiscal para executar consultas e emissões de
  teste.

Não inclua certificado, senha, CSC, endpoint privado ou XML com dados reais no
repositório, nos logs ou em issues.

## Consulta de status com mTLS

O teste atualmente preparado consulta o status do serviço com certificado
cliente A1:

```sh
FLUTTER_FISCAL_SEFAZ_HOMOLOGATION=1 \
FLUTTER_FISCAL_SEFAZ_ENDPOINT=https://endpoint-oficial-de-homologacao \
FLUTTER_FISCAL_SEFAZ_UF=11 \
FLUTTER_FISCAL_SEFAZ_CUF=11 \
FLUTTER_FISCAL_SEFAZ_PFX=/caminho/fora-do-repositorio/teste.p12 \
FLUTTER_FISCAL_SEFAZ_PASSWORD='senha-fornecida-fora-do-repositorio' \
dart test test/sefaz_homologation_test.dart
```

O teste exige resposta HTTP bem-sucedida e corpo não vazio. Ele não declara
autorização fiscal de uma NF-e/NFC-e.

## Operações ainda dependentes de configuração externa

A biblioteca possui builders, assinatura, transporte, parser e testes locais
para autorização, recibo, consulta, eventos e inutilização. A execução real
dessas operações depende de um conjunto correto de endpoints por UF, versão do
serviço, certificado, ambiente, CSC e dados fiscais de homologação. Cada
operação deve ser autorizada pelo responsável antes de ser adicionada a uma
suíte executável.

Uma resposta desconhecida nunca deve ser tratada como autorização: consulte a
chave ou o recibo antes de decidir por novo envio.

## Limitações registradas

Na ausência dos recursos externos acima, a homologação real permanece
pendente. Os testes locais com transporte injetável, fixtures e respostas
sintéticas comprovam somente o comportamento determinístico da biblioteca; não
substituem a validação fiscal perante a SEFAZ.
