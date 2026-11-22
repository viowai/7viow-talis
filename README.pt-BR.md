<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Ícone do Talis"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

Escreva com clareza. Depois, envie para a IA.

Talis é um espaço de trabalho de prompts para macOS. Anote uma ideia, crie um prompt que você possa continuar editando e copie para a ferramenta de IA que já usa. Você pode responder perguntas para completar informações importantes ou salvar requisitos frequentes como modelos pessoais.

As revisões consecutivas usam as 3 rodadas mais recentes como contexto. Abra **Histórico de revisões** para consultar as entradas e os resultados da sessão atual. Use **Limpar** para começar outra tarefa.

## Instalação

### Instalar pelo DMG

Baixe o [Talis v1.0.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.0.1/talis-v1.0.1-macos-arm64-build42.dmg). Abra a imagem de disco, arraste `Talis.app` para **Aplicativos** e abra o app nessa pasta. É necessário um Mac com Apple Silicon e macOS 13 ou posterior.

O app tem assinatura ad-hoc e não foi notarizado pela Apple. Se o macOS bloquear a primeira abertura, confirme que o download veio deste repositório e, se a opção aparecer, selecione **Abrir Mesmo Assim** em **Ajustes do Sistema → Privacidade e Segurança**. Consulte as [instruções da Apple para abrir apps](https://support.apple.com/en-us/102445).

Para compilar o código-fonte, são necessárias as ferramentas do Xcode 26 ou posterior, incluindo o SDK do macOS 26 ou posterior. A compilação foi verificada em Apple Silicon; Intel ainda não foi verificado. Não é necessária uma assinatura paga do Apple Developer. O projeto não tem dependências Swift Package de terceiros.

### Instalar pelo código-fonte

No Terminal:

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

Se as ferramentas da Apple não estiverem instaladas, execute `xcode-select --install` e conclua a solicitação do sistema. Se o Talis estiver aberto, salve seu texto e encerre o app antes da instalação. Modelos pessoais e ajustes ficam preservados fora do pacote do app.

## Primeiro uso

Você pode editar e copiar prompts sem configurar uma API Key:

1. Abra o Talis e pressione `Option + Space`.
2. Digite seu pedido, pressione `Command + Return` para copiá-lo e cole na ferramenta de IA que preferir.

Para revisar o texto com IA, abra **Ajustes do Serviço de IA** pelo botão de engrenagem. Escolha **API Key** ou **Assinatura**, selecione um serviço e uma região e salve. Depois, use **Aprimorar**, **Reescrever** ou **Pergunte-me**. O resultado continua editável; quando terminar, use **Copiar Prompt Cmd+Return**.

## Serviços de IA e dados

Edição, seleção de modelos e cópia funcionam offline. Aprimorar, reescrever, perguntar e gerar modelos com IA exigem um serviço disponível. Provedores com API Key cobram conforme as próprias condições. O modo Assinatura usa a assinatura do produto de IA já conectado neste Mac e não exige uma API Key separada.

As API Keys são salvas no Chaveiro do macOS, separadas por provedor. O modo Assinatura usa o produto conectado localmente e não copia nem salva seu token OAuth. A disponibilidade de modelos, contas, regiões e cotas depende de cada serviço. Consulte [serviços de IA](docs/ai-services.en.md) e [privacidade e dados](docs/privacy.en.md).

O Talis copia texto para a área de transferência. Ele não envia pedidos por você nem transfere anexos. Prompt Service e Talis Codex não fazem parte desta versão para desktop.

## Comentários e licença

Para relatar um problema, abra uma [GitHub Issue](https://github.com/viowai/7viow-talis/issues) com a versão do app, versão do macOS, tipo de chip, etapas e detalhes do erro. Remova API Keys e dados privados antes de enviar.

Mantenedor: Viow. O código-fonte e a documentação original usam a [Apache License 2.0](LICENSE), Copyright 2026 Wenbin Li. Consulte [NOTICE](NOTICE) e [avisos de terceiros](THIRD-PARTY-NOTICES.md). Montserrat é distribuída sob SIL Open Font License 1.1.
