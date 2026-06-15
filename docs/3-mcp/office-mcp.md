# Office MCP

Servidor MCP para manipulacao de documentos Office e PDF.

## Localizacao

```
scripts/office_mcp.py
```

## Ferramentas Disponiveis (40+)

### Word (.docx)

| Ferramenta | Descricao |
|------------|-----------|
| `create_document` | Criar documento com elementos estruturados |
| `read_document` | Ler texto e tabelas de documento |
| `edit_document` | Adicionar elementos a documento existente |
| `create_document_from_template` | Criar documento a partir de modelo |
| `create_document_from_example` | Criar documento replicando estilo |
| `add_image_to_document` | Inserir imagem em documento |
| `add_table_to_document` | Adicionar tabela formatada |
| `set_header_footer` | Configurar cabecalho/rodape |
| `manage_comments` | Gerenciar comentarios |
| `track_changes` | Aceitar/rejeitar alteracoes |
| `find_replace_tracked` | Localizar/substituir com tracking |
| `analyze_document_style` | Extrair informacoes de estilo |
| `save_style_profile` | Salvar perfil de estilo |
| `load_style_profile` | Carregar perfil de estilo |
| `convert_to_pdf` | Converter Word para PDF |
| `proteger_documento` | Proteger com senha |

### Excel (.xlsx/.xlsm)

| Ferramenta | Descricao |
|------------|-----------|
| `create_spreadsheet` | Criar planilha com multiplas abas |
| `read_spreadsheet` | Ler dados de aba especifica |
| `update_spreadsheet` | Atualizar celula com formatacao |
| `manage_rows_columns` | Inserir/remover linhas e colunas |
| `merge_cells` | Mesclar/desmesclar celulas |
| `conditional_formatting` | Aplicar formatacao condicional |
| `create_chart` | Criar grafico (bar, column, line, pie) |
| `manage_sheets` | Gerenciar abas |
| `add_filter` | Adicionar autofiltro |
| `freeze_panes` | Congelar paineis |
| `create_pivot_table` | Criar tabela dinamica |
| `create_dashboard` | Criar dashboard com KPIs |
| `analyze_spreadsheet_style` | Extrair estilos |
| `create_spreadsheet_from_example` | Criar replicando estilo |
| `create_macro_workbook` | Criar arquivo com macros VBA |
| `run_macro` | Executar macro VBA |
| `atualizar_power_query` | Atualizar Power Query |

### PowerPoint (.pptx)

| Ferramenta | Descricao |
|------------|-----------|
| `create_presentation` | Criar apresentacao |
| `read_presentation` | Ler estrutura de slides |
| `add_image_to_slide` | Inserir imagem em slide |
| `manage_slides` | Gerenciar slides |
| `change_slide_layout` | Alterar layout do slide |
| `add_shape` | Adicionar forma geometrica |
| `add_table_to_slide` | Adicionar tabela a slide |
| `edit_slide_text` | Editar texto de shape |
| `add_chart_to_slide` | Adicionar grafico nativo |
| `add_animation` | Adicionar efeito de animacao |
| `set_transition` | Configurar transicao |
| `add_smart_art` | Adicionar SmartArt |
| `analyze_presentation_style` | Extrair tema e cores |
| `create_presentation_from_example` | Criar replicando estilo |

### PDF e OCR

| Ferramenta | Descricao |
|------------|-----------|
| `extrair_texto_pdf` | Extrair texto e tabelas de PDF |
| `ocr_documento` | OCR em imagens de documentos |

## Framework

- **Servidor**: FastMCP (SDK MCP Python)
- **Execucao**: Subprocesso via Python
- **Blindagem**: ExecutionPolicy Bypass, UTF-8, timeout 60s

## Dependencias

```
pip install openpyxl python-docx python-pptx pywin32 mcp psutil formulas msal pdf2image lxml
pip install power-pptx excelize dumont docx-revisions PyMuPDF easyocr msoffcrypto-tool pandas
```

## Uso

O LLM automaticamente descobre e usa essas ferramentas quando o usuario pede para criar/modificar documentos Office.
