import os
import shutil
import sys
import json
from mcp.server.fastmcp import FastMCP

# Inicializa o servidor FastMCP
mcp = FastMCP("Office", instructions="""
Este servidor fornece ferramentas locais para criar, ler e modificar arquivos Word (.docx), Excel (.xlsx/.xlsm) e PowerPoint (.pptx).
Ele também fornece suporte para criar, adicionar e rodar macros VBA no Windows.
IMPORTANTE: Se o usuário pedir para criar ou modificar uma macro mas não especificar claramente as regras ou o comportamento da mesma,
você DEVE pedir esclarecimentos antes de prosseguir.
""")

# Importações preguiçosas para evitar falhas se as dependências não estiverem instaladas durante a descoberta inicial
def get_docx():
    import docx
    return docx

def get_openpyxl():
    import openpyxl
    return openpyxl

def get_pptx():
    import pptx
    return pptx

def get_win32():
    import win32com.client
    return win32com.client


# ==========================================
# 1. FERRAMENTAS WORD (.docx)
# ==========================================

@mcp.tool()
def create_document(file_path: str, elements: list) -> str:
    """
    Cria um novo documento Word (.docx) a partir de uma lista de elementos estruturados.
    
    Args:
        file_path: O caminho onde o arquivo sera salvo.
        elements: Lista de dicionarios contendo { 'type': 'title'|'heading1'|'heading2'|'paragraph'|'list_item', 'text': str, 'bold': bool, 'italic': bool }
    """
    docx = get_docx()
    doc = docx.Document()
    
    for el in elements:
        el_type = el.get("type", "paragraph")
        text = el.get("text", "")
        
        if el_type == "title":
            doc.add_heading(text, level=0)
        elif el_type == "heading1":
            doc.add_heading(text, level=1)
        elif el_type == "heading2":
            doc.add_heading(text, level=2)
        elif el_type == "list_item":
            p = doc.add_paragraph(style='List Bullet')
            run = p.add_run(text)
            run.bold = el.get("bold", False)
            run.italic = el.get("italic", False)
        else:
            p = doc.add_paragraph()
            run = p.add_run(text)
            run.bold = el.get("bold", False)
            run.italic = el.get("italic", False)
            
    doc.save(file_path)
    return f"Documento Word criado com sucesso em: {os.path.abspath(file_path)}"


@mcp.tool()
def read_document(file_path: str) -> str:
    """
    Le e extrai todo o texto estruturado de um documento Word (.docx), incluindo tabelas.
    """
    docx = get_docx()
    if not os.path.exists(file_path):
        return f"Erro: Arquivo nao encontrado em {file_path}"
        
    doc = docx.Document(file_path)
    result = []
    
    result.append(f"--- Documento: {os.path.basename(file_path)} ---")
    for p in doc.paragraphs:
        if p.text.strip():
            result.append(p.text)
            
    if doc.tables:
        result.append("\n--- Tabelas Encontradas ---")
        for i, table in enumerate(doc.tables):
            result.append(f"Tabela {i+1}:")
            for row in table.rows:
                row_text = [cell.text.strip() for cell in row.cells]
                result.append(" | ".join(row_text))
                
    return "\n".join(result)


@mcp.tool()
def create_document_from_template(template_path: str, output_path: str, replacements: dict) -> str:
    """
    Clona um documento base (.docx) e substitui marcadores de texto (ex: {{NomeCliente}}), 
    preservando 100% da formatacao original do modelo.
    """
    docx = get_docx()
    if not os.path.exists(template_path):
        return f"Erro: Modelo nao encontrado em {template_path}"
        
    shutil.copyfile(template_path, output_path)
    doc = docx.Document(output_path)
    
    # Substituir no texto comum
    for p in doc.paragraphs:
        for run in p.runs:
            for key, val in replacements.items():
                if key in run.text:
                    run.text = run.text.replace(key, str(val))
                    
    # Substituir dentro de tabelas
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for p in cell.paragraphs:
                    for run in p.runs:
                        for key, val in replacements.items():
                            if key in run.text:
                                run.text = run.text.replace(key, str(val))
                                
    doc.save(output_path)
    return f"Documento gerado a partir do modelo com sucesso em: {os.path.abspath(output_path)}"


# ==========================================
# 2. FERRAMENTAS EXCEL (.xlsx / .xlsm)
# ==========================================

@mcp.tool()
def create_spreadsheet(file_path: str, sheets_data: dict) -> str:
    """
    Cria uma nova planilha Excel (.xlsx) com dados estruturados.
    
    Args:
        file_path: O caminho de destino da planilha.
        sheets_data: Dicionario contendo { 'NomeDaAba': [ [col1, col2], [dados1, dados2] ] }
    """
    openpyxl = get_openpyxl()
    wb = openpyxl.Workbook()
    
    # Remove aba padrao
    default_sheet = wb.active
    wb.remove(default_sheet)
    
    for sheet_name, rows in sheets_data.items():
        ws = wb.create_sheet(title=sheet_name)
        for row in rows:
            ws.append(row)
            
    wb.save(file_path)
    return f"Planilha Excel criada com sucesso em: {os.path.abspath(file_path)}"


@mcp.tool()
def read_spreadsheet(file_path: str, sheet_name: str = None) -> str:
    """
    Le as linhas e colunas de uma aba especifica (ou da primeira aba ativa) de um arquivo Excel.
    """
    openpyxl = get_openpyxl()
    if not os.path.exists(file_path):
        return f"Erro: Planilha nao encontrada em {file_path}"
        
    # keep_vba=True para nao quebrar se for .xlsm
    wb = openpyxl.load_workbook(file_path, data_only=True, keep_vba=True)
    
    if not sheet_name:
        ws = wb.active
    else:
        if sheet_name not in wb.sheetnames:
            return f"Erro: Aba '{sheet_name}' nao existe nesta planilha. Abas: {wb.sheetnames}"
        ws = wb[sheet_name]
        
    result = []
    result.append(f"--- Planilha: {os.path.basename(file_path)} | Aba: {ws.title} ---")
    
    for row in ws.iter_rows(values_only=True):
        if any(cell is not None for cell in row):
            row_str = [str(cell) if cell is not None else "" for cell in row]
            result.append(" | ".join(row_str))
            
    return "\n".join(result)


@mcp.tool()
def update_spreadsheet(file_path: str, sheet_name: str, cell: str, value: str, format_options: dict = None) -> str:
    """
    Atualiza o valor e a formatacao de uma celula especifica de uma planilha Excel, preservando macros.
    
    Args:
        file_path: Caminho da planilha.
        sheet_name: Nome da aba.
        cell: Coordenada da celula (ex: 'A1').
        value: O novo valor a ser inserido.
        format_options: Dicionario opcional contendo { 'bold': bool, 'italic': bool, 'font_color': str (HEX), 'bg_color': str (HEX), 'font_size': int, 'number_format': str }
    """
    openpyxl = get_openpyxl()
    if not os.path.exists(file_path):
        return f"Erro: Planilha nao encontrada em {file_path}"
        
    wb = openpyxl.load_workbook(file_path, keep_vba=True)
    if sheet_name not in wb.sheetnames:
        return f"Erro: Aba '{sheet_name}' nao encontrada."
        
    ws = wb[sheet_name]
    c = ws[cell]
    c.value = value
    
    if format_options:
        from openpyxl.styles import Font, PatternFill
        
        # Fonte
        font_args = {}
        if "bold" in format_options: font_args["bold"] = format_options["bold"]
        if "italic" in format_options: font_args["italic"] = format_options["italic"]
        if "font_size" in format_options: font_args["size"] = format_options["font_size"]
        if "font_color" in format_options: font_args["color"] = format_options["font_color"]
        if font_args:
            c.font = Font(**font_args)
            
        # Cor de Fundo (Preenchimento)
        if "bg_color" in format_options:
            c.fill = PatternFill(start_color=format_options["bg_color"], 
                                 end_color=format_options["bg_color"], 
                                 fill_type="solid")
                                 
        # Formato Numerico (ex: R$ #,##0.00)
        if "number_format" in format_options:
            c.number_format = format_options["number_format"]
            
    wb.save(file_path)
    return f"Celula {cell} atualizada com sucesso na planilha {os.path.basename(file_path)}."


# ==========================================
# 3. FERRAMENTAS POWERPOINT (.pptx)
# ==========================================

@mcp.tool()
def create_presentation(file_path: str, slides: list) -> str:
    """
    Cria uma apresentacao de slides do PowerPoint (.pptx).
    
    Args:
        file_path: O caminho onde o arquivo sera salvo.
        slides: Lista de dicionarios contendo { 'title': str, 'bullet_points': [str] }
    """
    pptx = get_pptx()
    prs = pptx.Presentation()
    
    # 0 = layout de titulo, 1 = layout de titulo + conteudo
    title_slide_layout = prs.slide_layouts[0]
    bullet_slide_layout = prs.slide_layouts[1]
    
    for i, s_data in enumerate(slides):
        title = s_data.get("title", "")
        bullets = s_data.get("bullet_points", [])
        
        if i == 0 and not bullets:
            # Primeiro slide e slide de titulo
            slide = prs.slides.add_slide(title_slide_layout)
            slide.shapes.title.text = title
        else:
            slide = prs.slides.add_slide(bullet_slide_layout)
            slide.shapes.title.text = title
            
            tf = slide.placeholders[1].text_frame
            for bullet in bullets:
                p = tf.add_paragraph()
                p.text = bullet
                p.level = 0
                
    prs.save(file_path)
    return f"Apresentacao criada com sucesso em: {os.path.abspath(file_path)}"


@mcp.tool()
def read_presentation(file_path: str) -> str:
    """
    Le a estrutura de slides e todos os topicos de texto de uma apresentacao PowerPoint (.pptx).
    """
    pptx = get_pptx()
    if not os.path.exists(file_path):
        return f"Erro: Apresentacao nao encontrada em {file_path}"
        
    prs = pptx.Presentation(file_path)
    result = []
    
    result.append(f"--- Apresentacao: {os.path.basename(file_path)} ---")
    for i, slide in enumerate(prs.slides):
        result.append(f"\n[Slide {i+1}]")
        for shape in slide.shapes:
            if shape.has_text_frame:
                for paragraph in shape.text_frame.paragraphs:
                    if paragraph.text.strip():
                        result.append(f"  - {paragraph.text.strip()}")
                        
    return "\n".join(result)


@mcp.tool()
def add_image_to_slide(file_path: str, slide_index: int, image_path: str, left_inch: float, top_inch: float, width_inch: float = None, height_inch: float = None) -> str:
    """
    Insere uma imagem local em um slide especifico de uma apresentacao.
    
    Args:
        file_path: O caminho do arquivo .pptx.
        slide_index: Indice do slide (0-based).
        image_path: Caminho da imagem local a ser inserida.
        left_inch: Posicao horizontal em polegadas.
        top_inch: Posicao vertical em polegadas.
        width_inch: Largura opcional da imagem em polegadas.
        height_inch: Altura opcional da imagem em polegadas.
    """
    pptx = get_pptx()
    from pptx.util import Inches
    
    if not os.path.exists(file_path):
        return f"Erro: Apresentacao nao encontrada em {file_path}"
    if not os.path.exists(image_path):
        return f"Erro: Imagem nao encontrada em {image_path}"
        
    prs = pptx.Presentation(file_path)
    if slide_index < 0 or slide_index >= len(prs.slides):
        return f"Erro: Indice de slide {slide_index} invalido. Total de slides: {len(prs.slides)}"
        
    slide = prs.slides[slide_index]
    
    l = Inches(left_inch)
    t = Inches(top_inch)
    w = Inches(width_inch) if width_inch else None
    h = Inches(height_inch) if height_inch else None
    
    slide.shapes.add_picture(image_path, l, t, width=w, height=h)
    prs.save(file_path)
    return f"Imagem inserida com sucesso no slide {slide_index+1} da apresentacao {os.path.basename(file_path)}."


# ==========================================
# 4. CRIAÇÃO E CONTROLE DE MACROS VBA (Windows)
# ==========================================

@mcp.tool()
def create_macro_workbook(file_path: str, vba_code: str, module_name: str = "Module1") -> str:
    """
    Cria um novo arquivo Excel habilitado para macros (.xlsm) e injeta o codigo de macro VBA fornecido.
    IMPORTANTE: Caso as instrucoes do usuario sobre as regras da macro nao estejam claras, peca esclarecimentos antes de chamar esta ferramenta.
    
    Args:
        file_path: Caminho do arquivo a ser criado (deve terminar com .xlsm).
        vba_code: O codigo fonte VBA bruto da macro (ex: Sub MinhaMacro() ... End Sub).
        module_name: O nome do modulo a ser criado.
    """
    if not file_path.lower().endswith(".xlsm"):
        return "Erro: O caminho do arquivo para macros deve possuir extensao '.xlsm'"
        
    win32 = get_win32()
    abs_path = os.path.abspath(file_path)
    
    # Inicia Excel de forma invisivel
    excel = win32.Dispatch("Excel.Application")
    excel.Visible = False
    excel.DisplayAlerts = False
    
    wb = excel.Workbooks.Add()
    try:
        # vbext_ct_StdModule = 1 (Modulo padrão)
        xl_module = wb.VBProject.VBComponents.Add(1)
        xl_module.Name = module_name
        xl_module.CodeModule.AddFromString(vba_code)
        
        # xlOpenXMLWorkbookMacroEnabled = 52 (Salva como .xlsm)
        wb.SaveAs(abs_path, FileFormat=52)
        wb.Close()
        return f"Arquivo com macro criado com sucesso em: {abs_path}"
    except Exception as e:
        wb.Close(SaveChanges=False)
        return (f"Erro ao injetar macro. Certifique-se de que a opcao 'Confiar no acesso ao modelo de "
                f"objeto do projeto VBA' esta marcada na Central de Confiabilidade do Excel. Detalhes: {str(e)}")
    finally:
        excel.Quit()


@mcp.tool()
def run_macro(file_path: str, macro_name: str) -> str:
    """
    Abre uma planilha ou documento e executa a macro VBA especificada.
    
    Args:
        file_path: O caminho do arquivo (.xlsm ou .docm).
        macro_name: O nome da macro a ser executada (ex: 'MinhaPlanilha.xlsm!NomeDaSub').
    """
    win32 = get_win32()
    abs_path = os.path.abspath(file_path)
    
    if file_path.lower().endswith((".xlsm", ".xls")):
        excel = win32.Dispatch("Excel.Application")
        excel.Visible = False
        excel.DisplayAlerts = False
        try:
            wb = excel.Workbooks.Open(abs_path)
            excel.Application.Run(macro_name)
            wb.Save()
            wb.Close()
            return f"Macro '{macro_name}' executada com sucesso no Excel."
        except Exception as e:
            return f"Erro ao rodar macro no Excel: {str(e)}"
        finally:
            excel.Quit()
            
    elif file_path.lower().endswith((".docm", ".doc")):
        word = win32.Dispatch("Word.Application")
        word.Visible = False
        word.DisplayAlerts = False
        try:
            doc = word.Documents.Open(abs_path)
            word.Application.Run(macro_name)
            doc.Save()
            doc.Close()
            return f"Macro '{macro_name}' executada com sucesso no Word."
        except Exception as e:
            return f"Erro ao rodar macro no Word: {str(e)}"
        finally:
            word.Quit()
    else:
        return "Erro: Formato de arquivo nao suportado para execucao direta de macros."


if __name__ == "__main__":
    # Roda o servidor stdio
    mcp.run()
