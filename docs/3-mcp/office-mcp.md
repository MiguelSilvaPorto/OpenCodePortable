# Office MCP

Servidor MCP para manipulacao de documentos Office e PDF.

## Localizacao

```
scripts/office_mcp.py
```

## Ferramentas Disponiveis (53)

### Word (.docx) — 17 tools

| Ferramenta | Descricao |
|------------|-----------|
| `create_document_word` | Criar documento com elementos estruturados |
| `read_document_word` | Ler texto e tabelas de documento |
| `edit_document_word` | Editar elemento especifico por posicao |
| `append_to_document_word` | Adicionar conteudo ao FINAL sem sobrescrever |
| `get_document_info_word` | Contar paginas, paragrafos, caracteres (SEM modificar) |
| `create_document_from_template_word` | Criar documento a partir de modelo com substituicao |
| `create_document_from_example_word` | Criar documento replicando estilo de exemplo |
| `add_image_to_document_word` | Inserir imagem em documento |
| `add_table_to_document_word` | Adicionar tabela formatada |
| `set_header_footer_word` | Configurar cabecalho/rodape com numero de pagina |
| `manage_comments_word` | Adicionar, listar, responder e remover comentarios |
| `track_changes_word` | Ativar/desativar controle de alteracoes |
| `find_replace_tracked_word` | Localizar/substituir com tracking de alteracoes |
| `analyze_document_style_word` | Extrair fontes, cores e tamanhos do documento |
| `save_style_profile_word` | Salvar perfil de estilo para reutilizacao |
| `load_style_profile_word` | Carregar perfil de estilo salvo |
| `convert_to_pdf_word` | Converter Word para PDF (requer LibreOffice) |

### Excel (.xlsx/.xlsm) — 15 tools

| Ferramenta | Descricao |
|------------|-----------|
| `create_spreadsheet_excel` | Criar planilha com multiplas abas e formatacao |
| `read_spreadsheet_excel` | Ler dados de aba especifica |
| `update_spreadsheet_excel` | Atualizar celula com formatacao |
| `manage_rows_columns_excel` | Inserir/remover linhas e colunas |
| `merge_cells_excel` | Mesclar/desmesclar celulas |
| `conditional_formatting_excel` | Aplicar formatacao condicional |
| `create_chart_excel` | Criar grafico (bar, column, line, pie, scatter) |
| `manage_sheets_excel` | Renomear, copiar, mover, deletar abas |
| `add_filter_excel` | Adicionar autofiltro em colunas |
| `freeze_panes_excel` | Congelar paineis para navegacao |
| `atualizar_power_query_excel` | Atualizar queries Power Query |
| `create_pivot_table_excel` | Criar tabela dinamica com campos |
| `create_dashboard_excel` | Criar dashboard com KPIs e metricas |
| `analyze_spreadsheet_style_excel` | Extrair estilos do documento |
| `create_spreadsheet_from_example_excel` | Criar replicando estilo |

### PowerPoint (.pptx) — 16 tools

| Ferramenta | Descricao |
|------------|-----------|
| `create_presentation_pptx` | Criar apresentacao com slides estruturados |
| `read_presentation_pptx` | Ler estrutura e texto dos slides |
| `add_image_to_slide_pptx` | Inserir imagem em slide especifico |
| `manage_slides_pptx` | Adicionar, remover, duplicar, reordenar slides |
| `change_slide_layout_pptx` | Alterar layout do slide |
| `add_shape_pptx` | Adicionar forma geometrica com texto |
| `add_table_to_slide_pptx` | Adicionar tabela a slide |
| `edit_slide_text_pptx` | Editar texto de shape especifico |
| `add_chart_to_slide_pptx` | Adicionar grafico nativo PowerPoint |
| `add_animation_pptx` | Adicionar efeito de animacao a elementos |
| `set_transition_pptx` | Configurar transicao entre slides |
| `add_smart_art_pptx` | Adicionar SmartArt (listas, processos, hierarquias) |
| `analyze_presentation_style_pptx` | Extrair tema, cores e fontes |
| `create_presentation_from_example_pptx` | Criar replicando estilo |
| `list_template_slots_pptx` | Listar slots editaveis de um template |
| `create_from_template_pptx` | Criar PPTX a partir de template com substituicoes |

### VBA — 2 tools

| Ferramenta | Descricao |
|------------|-----------|
| `create_macro_workbook_vba` | Criar workbook Excel com macros VBA |
| `run_macro_vba` | Executar macro VBA em arquivo Excel |

### PDF e OCR — 3 tools

| Ferramenta | Descricao |
|------------|-----------|
| `extract_text_pdf` | Extrair texto e tabelas de PDF |
| `ocr_document` | OCR em imagens de documentos |
| `protect_document` | Proteger documento com senha |

## Importante: create vs append

| Ferramenta | Comportamento |
|------------|---------------|
| `create_document_word` | **SOBRESCREVE** o arquivo inteiro |
| `append_to_document_word` | **ADICIONA** ao final, preserva tudo |
| `get_document_info_word` | **NAO modifica** o arquivo (só leitura) |

**Regra de ouro:** Para documentos grandes, use `append_to_document_word` em vez de `create_document_word` para nao perder conteudo.

## Framework

- **Servidor**: FastMCP (SDK MCP Python)
- **Execucao**: Subprocesso via Python
- **Blindagem**: ExecutionPolicy Bypass, UTF-8, timeout 60s

## Dependencias

```
pip install openpyxl python-docx python-pptx pywin32 mcp psutil formulas msal pdf2image lxml
pip install power-pptx excelize dumont docx-revisions PyMuPDF easyocr msoffcrypto-tool pandas
```

## Portabilidade

Os caminhos MCP sao **automaticamente corrigidos** a cada execucao do `opencode.bat` ou `opencode.ps1` via `scripts/update_config.js`. Todos os caminhos sao relativos.

## Uso

O LLM automaticamente descobre e usa essas ferramentas quando o usuario pede para criar/modificar documentos Office.

## Criacao de Apresentacoes Profissionais com Templates

Para criar apresentacoes com qualidade profissional (estilo Slidesgo/SlidesCarnival), use o sistema de templates baseado em clonagem.

### Templates Disponiveis

| Template | Estilo | Slides | Caminho |
|----------|--------|--------|---------|
| `clean_minimal` | Clean/Minimal/Moderno | 25 | `./data/templates/clean_minimal.pptx` |
| `scrapbook_nature` | Artistico/Journal | 15 | `./data/templates/scrapbook_nature.pptx` |

### Fluxo de Trabalho

1. **Listar slots** do template para descobrir os indices editaveis:
   ```
   list_template_slots_pptx(template_path="./data/templates/clean_minimal.pptx")
   ```
   Retorna JSON com `slide_index` e `shape_index` de cada slot.

2. **Criar com substituicoes**:
   ```
   create_from_template_pptx(
     template_path="./data/templates/clean_minimal.pptx",
     output_path="./projeto/astronomia.pptx",
     slide_replacements='{
       "0": {"10": "Ola Mundo", "11": "2026"},
       "2": {"3": "SUMARIO"}
     }'
   )
   ```

3. **Resultado**: Nova apresentacao criada com formatacao 100% preservada (cores, fontes, layouts, imagens). Apenas os textos nos shapes especificados sao substituidos.

### Vantagens deste Sistema

- **Formatacao 100% preservada** - cores, fontes, layouts, imagens decorativas
- **Visual profissional real** - layouts testados por designers
- **Reaproveitamento** - mesmo template pode ser usado para varios projetos
- **Identificacao precisa** - cada shape tem indice unico, sem ambiguidade
