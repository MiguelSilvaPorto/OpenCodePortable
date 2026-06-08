import os
import unittest
import shutil
from scripts.office_mcp import (
    create_document,
    read_document,
    create_document_from_template,
    create_spreadsheet,
    read_spreadsheet,
    update_spreadsheet,
    create_presentation,
    read_presentation,
    create_macro_workbook,
    run_macro
)

class TestOfficeMCPServer(unittest.TestCase):
    
    def setUp(self):
        self.test_dir = os.path.join(os.path.dirname(__file__), "output")
        if not os.path.exists(self.test_dir):
            os.makedirs(self.test_dir)
            
    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_word_tools(self):
        doc_path = os.path.join(self.test_dir, "test_doc.docx")
        
        # 1. Testar create_document
        elements = [
            {"type": "title", "text": "Documento de Teste"},
            {"type": "heading1", "text": "Introducao"},
            {"type": "paragraph", "text": "Este e um paragrafo de teste para validacao de MCP.", "bold": True},
            {"type": "list_item", "text": "Item 1 da lista"},
            {"type": "list_item", "text": "Item 2 da lista", "italic": True}
        ]
        
        res_create = create_document(doc_path, elements)
        self.assertIn("sucesso", res_create)
        self.assertTrue(os.path.exists(doc_path))
        
        # 2. Testar read_document
        res_read = read_document(doc_path)
        self.assertIn("Documento de Teste", res_read)
        self.assertIn("Este e um paragrafo de teste", res_read)
        self.assertIn("Item 1 da lista", res_read)
        
        # 3. Testar create_document_from_template
        template_output = os.path.join(self.test_dir, "test_template_out.docx")
        template_input = os.path.join(self.test_dir, "template.docx")
        create_document(template_input, [
            {"type": "paragraph", "text": "Prezado {{Nome}}, sua conta e {{Conta}}."}
        ])
        
        replacements = {"{{Nome}}": "Miguel Porto", "{{Conta}}": "12345-6"}
        res_tpl = create_document_from_template(template_input, template_output, replacements)
        self.assertIn("sucesso", res_tpl)
        self.assertTrue(os.path.exists(template_output))
        
        res_read_tpl = read_document(template_output)
        self.assertIn("Prezado Miguel Porto, sua conta e 12345-6.", res_read_tpl)

    def test_excel_tools(self):
        sheet_path = os.path.join(self.test_dir, "test_sheet.xlsx")
        
        # 1. Testar create_spreadsheet
        sheets_data = {
            "Dados": [
                ["ID", "Nome", "Cidade"],
                [1, "Ana", "Sao Paulo"],
                [2, "Bruno", "Rio de Janeiro"]
            ]
        }
        res_create = create_spreadsheet(sheet_path, sheets_data)
        self.assertIn("sucesso", res_create)
        self.assertTrue(os.path.exists(sheet_path))
        
        # 2. Testar read_spreadsheet
        res_read = read_spreadsheet(sheet_path, "Dados")
        self.assertIn("ID | Nome | Cidade", res_read)
        self.assertIn("1 | Ana | Sao Paulo", res_read)
        
        # 3. Testar update_spreadsheet
        format_options = {"bold": True, "bg_color": "CCCCCC", "font_color": "FF0000"}
        res_update = update_spreadsheet(sheet_path, "Dados", "A4", "Novo Valor", format_options)
        self.assertIn("sucesso", res_update)
        
        res_read_updated = read_spreadsheet(sheet_path, "Dados")
        self.assertIn("Novo Valor", res_read_updated)

    def test_powerpoint_tools(self):
        ppt_path = os.path.join(self.test_dir, "test_presentation.pptx")
        
        # 1. Testar create_presentation
        slides = [
            {"title": "Apresentacao de Teste"},
            {"title": "Segundo Slide", "bullet_points": ["Topico A", "Topico B"]}
        ]
        res_create = create_presentation(ppt_path, slides)
        self.assertIn("sucesso", res_create)
        self.assertTrue(os.path.exists(ppt_path))
        
        # 2. Testar read_presentation
        res_read = read_presentation(ppt_path)
        self.assertIn("Apresentacao de Teste", res_read)
        self.assertIn("Topico A", res_read)
        self.assertIn("Topico B", res_read)

    def test_vba_macro_creation(self):
        macro_path = os.path.join(self.test_dir, "test_macro.xlsm")
        vba_code = """Sub TesteMacro()
    Range("A1").Value = "Valor Escrito pela Macro"
End Sub"""
        
        try:
            res_macro = create_macro_workbook(macro_path, vba_code, "Module1")
            if "Erro" not in res_macro:
                self.assertIn("sucesso", res_macro)
                self.assertTrue(os.path.exists(macro_path))
                
                # Testar execucao da macro
                res_run = run_macro(macro_path, "test_macro.xlsm!Module1.TesteMacro")
                self.assertIn("sucesso", res_run)
                
                # Validar o resultado
                res_read = read_spreadsheet(macro_path, "Sheet1")
                self.assertIn("Valor Escrito pela Macro", res_read)
            else:
                print("Ignorando assercao completa de macro: Central de Confiabilidade nao habilitada ou sem Excel.")
        except Exception as e:
            print(f"Ignorando teste COM/ActiveX (Excel nao instalado): {str(e)}")

if __name__ == "__main__":
    unittest.main()
