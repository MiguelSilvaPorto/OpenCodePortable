# Install Network Apps - IMCOPA

Script de instalação em massa para deploy de software em estações de trabalho Windows, a partir de um share de rede.

## Objetivo

Automatizar a instalação de 7 aplicativos (AnyDesk, Teams, TeamViewer 12, SAP GUI 7.50, Kaspersky, 7-Zip, Chrome) em múltiplas máquinas Windows, de forma:

- **Silenciosa** (sem interação do usuário)
- **Padronizada** (mesmas flags e configs em todas as máquinas)
- **Auditável** (log de cada instalação em arquivo)
- **Resiliente** (se uma app falhar, as outras continuam)

## Estrutura de Arquivos

```
D:\
├── install.bat                       # Launcher (faz elevação UAC automática)
├── install-network-apps.bat          # Script principal (único .bat de instalacao)
├── apps-config.ini                   # Lista de apps com paths e argumentos
└── README.md                         # Este arquivo
```

## Como Usar

### Distribuição

Copie os 3 arquivos para a máquina alvo:
- `D:\install.bat`
- `D:\install-network-apps.bat`
- `D:\apps-config.ini`

### Execução

**Método 1 — Duplo-clique (recomendado):**
1. Duplo-clique em `D:\install.bat`
2. Aceite o prompt do UAC (clique "Sim")
3. O script roda automaticamente com janela visível
4. Aguarde a conclusão (pode levar 10-30 min dependendo da rede)

**Método 2 — CMD Admin:**
```bat
:: Abrir CMD como Administrador (Win+X → Terminal Admin)
cd /d D:\
install-network-apps.bat
```

## Pré-requisitos

- Windows 10/11
- Acesso ao share `\\monpro002\TI\` com permissão de leitura
- Credenciais de domínio válidas (ou share acessível)
- ~2 GB de espaço livre em `C:` (para installers temporários)
- ~500 MB em `%TEMP%` (para SAP installer)

## Aplicativos Instalados

| # | App | Tipo | Versão |
|---|-----|------|--------|
| 1 | AnyDesk | EXE (per-user) | 7.0.8 |
| 2 | Microsoft Teams | EXE (per-user) | Machine-wide installer |
| 3 | TeamViewer 12 | EXE (NSIS) | 12.x |
| 4 | SAP GUI 7.50 | EXE (NW 7.0 Pres. 7.50 Comp. 2) | + KW + KWHTML + i.s.h.med |
| 5 | Kaspersky Endpoint Security | INLINE (Agente + KES) | setup_kes.exe |
| 6 | 7-Zip | DOWNLOAD (de 7-zip.org) | 24.x |
| 7 | Google Chrome | EXE (offline) | 57.0.2987.133 |

## Como Funciona

### Fluxo

```
install.bat (launcher)
  ├── Detecta se é admin
  ├── Se não: Start-Process -Verb RunAs (UAC prompt)
  └── Executa install-network-apps.bat como admin

install-network-apps.bat
  ├── Header (3s delay)
  ├── Pre-checks (ini, admin, share)
  ├── Limpa flags de reboot pendente (4 chaves do registro)
  ├── Gera NWSAPSetupAdmin.ini (SAP)
  ├── Gera saplogon.ini (SAP QAS + PRD)
  └── Loop de instalação (lê apps-config.ini)
        ├── AnyDesk → install_exe (com workaround 7.0.8)
        ├── Teams → install_exe
        ├── TeamViewer → install_exe
        ├── SAP GUI → cópia LOCAL + install_exe (workaround share read-only)
        ├── Kaspersky → install_kaspersky (Agente → KES)
        ├── 7-Zip → install_download
        └── Chrome → install_exe
  └── Resumo final
```

### apps-config.ini — Formato

```ini
[SETTINGS]
ANYDESK_PASSWORD=Security@              # Senha do AnyDesk (uso pós-instalação)
LOG_DIR=%LOCALAPPDATA%\Logs\InstallNetworkApps
BITDEFENDER_PWD=@imcopaLeve07           # Senha para desinstalar Bitdefender
KASPERSKY_DIR=\\monpro002\TI\...\Kaspersky

[APPS]
; Formato: Nome=Tipo|Caminho|Executavel|Argumentos
; Tipos: EXE | DOWNLOAD | MSI | INLINE_KASPERSKY
AnyDesk=EXE|\\monpro002\TI\...|AnyDesk.exe|--install "C:\Program Files\AnyDesk" --start-with-win --silent
Kaspersky=INLINE_KASPERSKY|||
7Zip=DOWNLOAD|https://www.7-zip.org/a/7z2409-x64.exe||/S
```

Para adicionar/remover apps, edite apenas o `apps-config.ini` — o script lê dinamicamente.

## Saídas

### Console

O script imprime o progresso em tempo real:
- Pre-checks (OK/FALHA)
- Limpeza de reboot flags
- Geração dos .ini do SAP
- Cada app processado (`[1]`, `[2]`, ...)
- Erros de cada app
- Resumo final

### Log

Todos os eventos são salvos em:
```
%LOCALAPPDATA%\Logs\InstallNetworkApps\install_AAAAMMDD_HHMMSS.log
```

## Solução de Problemas

### Janela fecha imediatamente
- Execute via `install.bat` (não `install-network-apps.bat` direto)
- `install.bat` faz a elevação UAC automaticamente

### Erro "foi inesperado neste momento"
- Bug de parsing do batch
- Verifique se o `apps-config.ini` está em CP1252 (não UTF-8)
- Não edite o script com editores que salvam em UTF-8

### SAP GUI não instala silenciosamente
- O script copia o instalador para `%TEMP%` e gera o .ini lá
- Se mesmo assim aparecer GUI, a versão do SAP GUI é incompatível
- Workaround: instalar manualmente uma vez e copiar de `C:\Program Files\SAP\FrontEnd`

### Apps EXE não encontrados
- O script não conseguiu acessar `\\monpro002\TI\...`
- Verifique conectividade de rede e credenciais
- Para máquinas fora do domínio, o share precisa ser acessado com `net use`

### Kaspersky falha com "Pasta inacessível"
- O path de rede do Kaspersky não está acessível
- Verifique o caminho em `KASPERSKY_DIR` no `apps-config.ini`

### 7-Zip e Chrome precisam de internet
- 7-Zip é baixado de `https://www.7-zip.org`
- Se a máquina não tem internet, o download falha

## Encoding

Todos os arquivos estão em **CP1252** (Latin-1) para compatibilidade com o console do Windows em português. Acentos como `ã`, `ç`, `é` são representados por bytes únicos (0xE3, 0xE7, 0xE9).

**IMPORTANTE**: Não edite esses arquivos com editores que salvam em UTF-8 (como Notepad do Windows 11, VSCode padrão). Use:
- Notepad++ com encoding "ANSI" / "Windows-1252"
- Ou salve via PowerShell: `[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::GetEncoding(1252))`

## Manutenção

### Adicionar um novo app

1. Edite `apps-config.ini`
2. Adicione uma linha em `[APPS]`:
   ```ini
   NovoApp=EXE|\\servidor\caminho|setup.exe|/S
   ```
3. O script lê automaticamente na próxima execução

### Atualizar a versão de um app

1. Atualize o caminho no `apps-config.ini`
2. Atualize os argumentos se necessário
3. O script usa o novo caminho na próxima execução

### Mudar a senha do AnyDesk

1. Edite `apps-config.ini`
2. Altere `ANYDESK_PASSWORD=...`
3. O `{ANYDESK_PASSWORD}` é substituído automaticamente nos args

### Adicionar servidores SAP

1. Edite a seção do SAP no script (`install-network-apps.bat`)
2. Adicione um novo bloco `(echo ...)` no `saplogon.ini`
3. Use o formato: `[NOME_SERVIDOR]` + `AppServer=IP` + `SystemNumber=00` + `SystemId=XXX`

## Limitações Conhecidas

1. **SAP GUI 7.50 Compilação 2**: o instalador é antigo (2017) e tem comportamento de silent install inconsistente. O script usa workaround de cópia local, mas pode exigir clique manual em "Next" em algumas máquinas.

2. **AnyDesk 7.0.8**: a flag `--set-password` foi adicionada apenas em 8.x. O script configura o acesso unattended via registro e informa a senha para definição manual.

3. **Chrome 57.0.2987.133**: versão de 2017. Será auto-atualizado após instalação se houver internet.

4. **Paths com `+` e acentos**: o share tem pasta `MAIS USADOS +` com `ã` em `Padrão`. O script usa codepage 1252 para interpretar corretamente.

5. **Cópia do SAP installer**: o share é read-only na pasta do SAP installer. O script copia o instalador inteiro para `%TEMP%` localmente. Requer ~500MB de espaço temporário.

## Histórico de Versões

### v1.0 (2026-06)
- Instalação de 7 apps em script único
- Suporte a múltiplos tipos (EXE, DOWNLOAD, MSI, INLINE_KASPERSKY)
- Workaround para share read-only (SAP local copy)
- Limpeza de flags de reboot
- Geração de NWSAPSetupAdmin.ini e saplogon.ini
- Launcher com auto-elevação UAC
- Log em arquivo

## Suporte

Para problemas ou dúvidas:
1. Verifique o log em `%LOCALAPPDATA%\Logs\InstallNetworkApps\`
2. Verifique o encoding dos arquivos (devem ser CP1252)
3. Teste o acesso ao share `\\monpro002\TI\` com o usuário da máquina alvo
