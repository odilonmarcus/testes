# Conselho Jurídico IA — macOS

Aplicativo nativo em SwiftUI para colocar GPT e Claude em um debate jurídico estruturado: tese, contraditório, revisão, auditoria e parecer consolidado.

## O que o advogado precisa fazer

Depois que você entregar o `Conselho-Juridico-IA-macOS.dmg`, o uso é simples:

1. Abrir o DMG.
2. Arrastar **ConselhoJuridicoIA** para **Aplicativos**.
3. Abrir o aplicativo.
4. Na primeira execução, colar uma chave da OpenAI e uma chave da Anthropic.
5. Clicar em **Testar conexões**.
6. Clicar em **Salvar e começar**.
7. Escrever a questão, anexar um documento se necessário e iniciar a análise.

As chaves ficam no Keychain do macOS. O aplicativo não mantém banco de histórico das análises.

## Requisitos do usuário final

- macOS 13 Ventura ou superior.
- Conexão com a internet.
- Chave de API OpenAI com cobrança/API habilitada.
- Chave de API Anthropic com cobrança/API habilitada.

Assinaturas do ChatGPT ou Claude não substituem automaticamente as contas/chaves de API.

## Modelos padrão

- OpenAI: `gpt-6-sol`
- Anthropic: `claude-sonnet-5-5`

Os IDs podem ser alterados em Ajustes sem recompilar o aplicativo.

## Gerar o aplicativo em um Mac

Requisito de compilação: Xcode instalado.

### Forma mais simples

Dê duplo clique em:

`build_app.command`

O script:

1. compila a versão Release;
2. assina localmente para teste;
3. gera o aplicativo;
4. cria o DMG.

Resultado:

`dist/Conselho-Juridico-IA-macOS.dmg`

A versão produzida por esse script é adequada para teste. Como não é notarizada pela Apple, outro Mac pode exibir um aviso do Gatekeeper na primeira abertura.

## Gerar sem ter um Mac: GitHub Actions

O projeto inclui `.github/workflows/build-macos.yml`.

1. Crie um repositório privado no GitHub.
2. Envie o conteúdo desta pasta para o repositório.
3. Abra **Actions > Build macOS DMG > Run workflow**.
4. Ao terminar, baixe o artefato `Conselho-Juridico-IA-macOS`.

O GitHub usa um runner macOS e gera o DMG automaticamente. Essa versão também é para teste e não é notarizada.

## Distribuição profissional sem avisos do macOS

Para o advogado receber um aplicativo que abre normalmente, sem contornar o Gatekeeper, recomenda-se:

- conta Apple Developer;
- certificado **Developer ID Application**;
- notarização da Apple.

O script `release_notarized.command` automatiza build, assinatura, DMG, notarização e stapling. Antes de executá-lo, configure:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Sua Empresa (TEAMID)"
export NOTARY_PROFILE="conselho-juridico"
./release_notarized.command
```

O perfil do notarytool é criado uma única vez com:

```bash
xcrun notarytool store-credentials conselho-juridico
```

## Privacidade e segurança

- OpenAI: chamadas pela Responses API com `store: false`.
- Anthropic: chamadas diretas pela Messages API.
- Não há servidor intermediário próprio no projeto atual.
- As credenciais ficam no Keychain deste Mac.
- O sandbox permite rede e leitura/escrita apenas de arquivos selecionados pelo usuário.
- A sessão não é gravada em banco local.
- O conteúdo continua sujeito às políticas de retenção, contrato e configurações dos provedores.

Para informações protegidas por sigilo profissional, defina previamente a política do escritório para uso de provedores de IA e os tipos de informação que podem ser enviados.

## Documentos

A versão atual lê:

- PDF com texto pesquisável;
- TXT;
- RTF.

PDFs apenas escaneados precisam de OCR antes da importação. O aplicativo avisa quando detecta PDF sem texto pesquisável.

## Funcionamento do debate

1. GPT — Advogado da tese.
2. Claude — Advogado do contraditório.
3. GPT — Revisão da tese.
4. Claude — Auditoria.
5. As rodadas se repetem conforme a profundidade escolhida.
6. GPT — Relator neutro, gerando o parecer consolidado.

Os prompts proíbem a invenção deliberada de legislação, jurisprudência, processos e fatos e instruem o modelo a marcar pontos inseguros como **VALIDAR EM FONTE OFICIAL**. Isso reduz risco, mas não elimina erros de modelos de IA.
