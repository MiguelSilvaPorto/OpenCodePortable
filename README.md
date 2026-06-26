# OpenCode Portable

OpenCode Portable é um ambiente de execução portátil e pré-configurado para o assistente de desenvolvimento baseado em IA **OpenCode**. Este projeto foi projetado para facilitar o deploy e a execução do ecossistema OpenCode no sistema Windows sem a necessidade de instalações manuais complexas.

---

## 🎯 Objetivo do Projeto

O objetivo principal deste projeto é empacotar o cliente OpenCode e seus componentes em uma suíte totalmente portátil e resiliente. 
Ele visa:
1. **Instalação Simplificada**: Permitir que desenvolvedores executem o assistente instantaneamente a partir de um único instalador ou executando diretamente os scripts (`.bat` / `.ps1`).
2. **Ambiente Isolado**: Manter todas as dependências, configurações (como banco de dados `.brain` e chaves de APIs) e caches locais salvos de forma portátil dentro do diretório do projeto, sem alterar o sistema host.
3. **Resiliência de Dependências**: Verificar e instalar automaticamente o Git e o Python caso não estejam configurados no computador do usuário final.
4. **Orquestração de MCPs**: Habilitar a integração nativa e automatizada com até 5 servidores MCP (Model Context Protocol) como o NVIDIA Router, Brain MCP e Office MCP, exibindo o status ativo (bolinha verde) e pronto para uso no terminal.

---

## 🚀 Como Instalar e Configurar

O deploy do OpenCode Portable pode ser feito de duas formas:

### Método 1: Usando o Instalador Automatizado (Recomendado)
1. Baixe o instalador mais recente: **[OpenCodeSetup-beta_v1_r19.exe](https://github.com/MiguelSilvaPorto/OpenCodePortable/releases/download/vbeta_v1_r19/OpenCodeSetup-beta_v1_r19.exe)**.
2. Execute o instalador. Se uma versão anterior do OpenCode for detectada no seu sistema, o instalador perguntará de forma inteligente se você deseja:
   - **Desinstalar**: Realiza a desinstalação silenciosa da versão antiga para fazer uma instalação limpa.
   - **Atualizar**: Sobrescreve apenas os arquivos e atualiza a pasta atual de programas.
   - **Cancelar**: Aborta a instalação.
3. Escolha o diretório de destino. Por padrão, ele será instalado no seu diretório local de programas do usuário.
4. Marque a opção de criar atalho na Área de Trabalho.
5. Conclua o assistente. O instalador gerará atalhos configurados com os ícones oficiais do OpenCode no Menu Iniciar e Desktop.

### Método 2: Execução Direta (Portátil)
1. Baixe ou clone os arquivos do repositório para uma pasta local (ex: `D:\OpenCodePortable`).
2. Execute o launcher portátil sem necessitar de instalação.

---

## 🔄 Atualizações Automáticas

O OpenCode Portable possui um sistema de atualização inteligente integrado:
- Sempre que você iniciar o ambiente através do `opencode.ps1` ou `opencode.bat`, o launcher verificará no repositório GitHub se existe uma versão/release mais recente disponível.
- Se uma nova versão for detectada (ex: `vbeta_v1_r8` sendo mais recente que a instalada localmente), ele exibirá um aviso em amarelo e perguntará: `Deseja atualizar agora? (S/N)`.
- Se você responder **S** (Sim), ele fará o download automático do ZIP da nova versão (`opencode-windows-x64.zip`), extrairá os arquivos, atualizará o executável e reiniciará o aplicativo de forma automática e transparente.


---

## 💻 Como Usar

### Inicialização Rápida
Dê um duplo clique no arquivo **`opencode.bat`** localizado na raiz do projeto (ou execute `opencode.ps1` diretamente no PowerShell).

O launcher executará as seguintes etapas de forma automática e transparente:
1. **Auto-Elevação**: Executará como administrador (UAC) caso alguma dependência precise de permissões adicionais.
2. **Setup de Dependências**: Validará se o Git e o Python estão disponíveis. Se faltar o Git, ele fará o download silencioso através do `winget` ou `scoop`.
3. **Redirecionamento ao Windows Terminal**: Se disponível, ele reabrirá automaticamente a sessão no Windows Terminal para melhor suporte gráfico, cores e área de transferência.
4. **Resolução de MCPs e NVIDIA Router**: Iniciará os servidores de contexto em background e configurará os caminhos relativos de forma dinâmica.
5. **Seletor de Projetos**: Apresentará a tela de seleção de workspace para você escolher em qual projeto deseja trabalhar.

---

## 👥 Créditos e Licença

Este projeto é um fork portátil e customizado do cliente original.

- **Autor Original e Repositório**: Este projeto estende o trabalho fantástico desenvolvido originalmente no repositório oficial **[anomalyco/opencode](https://github.com/anomalyco/opencode)**. Agradecemos imensamente aos autores originais e à comunidade do OpenCode pelo desenvolvimento do núcleo da ferramenta.
- **Desenvolvimento do Fork Portátil**: Customizações no instalador (Inno Setup), correções de layout e lógica do launcher PowerShell mantidas no repositório **[MiguelSilvaPorto/OpenCodePortable](https://github.com/MiguelSilvaPorto/OpenCodePortable)**.
