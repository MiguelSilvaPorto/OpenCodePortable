# Install Office Deps

Script de instalacao das dependencias Python do Office MCP.

## Localizacao

```
scripts/install-office-deps.bat
```

## Funcionalidade

Instala todas as bibliotecas Python necessarias para o office-mcp funcionar.

## Fluxo

```
1. Verificar/Instalar Python via Scoop
2. Atualizar pip
3. Instalar bibliotecas base
4. Instalar bibliotecas avancadas
```

## Dependencias Instaladas

### Base (etapa 2)

| Pacote | Funcao |
|--------|--------|
| openpyxl | Manipulacao Excel |
| python-docx | Manipulacao Word |
| python-pptx | Manipulacao PowerPoint |
| pywin32 | Automacao COM |
| mcp | SDK MCP Python |

### Avancadas (etapa 3)

| Pacote | Funcao |
|--------|--------|
| power-pptx | Animacoes PowerPoint |
| excelize | PivotTable Excel |
| dumumont | Dashboards KPI |
| docx-revisions | Track Changes Word |
| PyMuPDF | Extracao texto PDF |
| easyocr | OCR em imagens |
| msoffcrypto-tool | Protecao por senha |

## Uso

```batch
scripts\install-office-deps.bat
```

## Notas

- Requer Python instalado (instala via Scoop se necessario)
- Pode exigir privilegios de administrador para pywin32
- Numeração incorreta no script: mostra [1/2] mas sao 3 passos
