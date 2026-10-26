# Segurança

Não envie certificados digitais, chaves privadas, tokens, XMLs reais ou dados pessoais em issues e pull requests.

Para relatar uma vulnerabilidade, use um canal privado do mantenedor e inclua passos de reprodução mínimos, impacto e versão afetada. Não publique a vulnerabilidade antes de existir uma correção ou orientação coordenada.

A biblioteca não deve registrar senhas, PINs de certificados, conteúdo de chaves privadas ou respostas completas da SEFAZ em logs de produção.

Para persistência em Flutter, use `FiscalSecretStore` com um backend seguro do
sistema operacional. `InMemoryFiscalSecretStore` existe apenas para testes e
não protege bytes contra leitura do processo ou do heap.

Os getters de material DER do certificado e da chave privada PKCS#8 retornam
cópias defensivas; o estado interno usado por assinatura e mTLS não é exposto
para mutação acidental. Certificados intermediários presentes no PFX são
encaminhados na cadeia cliente do mTLS; a validação de confiança continua
delegada às raízes confiáveis do sistema operacional/runtime TLS.

Ao carregar um PFX, `PfxIdentity` também assina uma prova efêmera em memória e
confere a assinatura com o certificado extraído. Um contêiner que combine
certificado e chave privada de identidades diferentes é rejeitado antes de ser
usado para XMLDSig ou mTLS.

`Certificate.verifyIssuedBy()` valida a assinatura RSA do `TBSCertificate`, a
relação `issuer`/`subject` e a validade temporal; `verifyChain()` e
`PfxIdentity.verifyCertificateChain()` permitem validar o caminho fornecido
pelo PFX ou por âncoras explícitas antes de uma decisão da aplicação.

Verificadores XMLDSig RSA tratam codificação Base64 inválida e assinaturas
malformadas como falha de verificação (`false`), evitando que entrada externa
malformada escape como exceção de parsing.

`NfeXmlValidator` rejeita `requireSignature: true` quando não recebe um
`signatureVerifier`; presença de `SignatureValue` e `DigestValue` sozinha não
é considerada prova criptográfica. `Tools.sefazValidate()` aplica a mesma
política e exige a chave pública/verificador configurado pela aplicação.

`Certificate.writePfx()` rejeita contêineres com menos de 2048 iterações de
derivação para evitar exportações deliberadamente fracas contra brute force.

