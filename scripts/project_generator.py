import os
import re
import shutil
import subprocess
import json
from mcp.server.fastmcp import FastMCP

# Inicializa o servidor FastMCP
mcp = FastMCP("ProjectGenerator", instructions="""
Este servidor fornece ferramentas locais para criar e isolar projetos de desenvolvimento em pastas físicas exclusivas.
Garante que cada chat/sessão tenha seu próprio workspace físico e limpo com Git inicializado.
""")

def _sanitizar_nome_projeto(nome: str) -> str:
    """Sanitiza o nome do projeto para ser um nome de pasta seguro no Windows."""
    # Remover acentos
    import unicodedata
    nome_normalized = unicodedata.normalize('NFKD', nome).encode('ASCII', 'ignore').decode('ASCII')
    # Substituir espaços por sublinhados
    nome_normalized = re.sub(r'\s+', '_', nome_normalized)
    # Remover caracteres não permitidos no Windows para pastas
    nome_normalized = re.sub(r'[\\/:*?"<>|]', '', nome_normalized)
    # Evitar nomes vazios ou que iniciem com pontos
    nome_normalized = nome_normalized.strip(' ._')
    if not nome_normalized:
        nome_normalized = "projeto_novo"
    return nome_normalized

@mcp.tool()
def create_isolated_project(project_name: str, mode: str = "local") -> str:
    """
    Cria uma nova pasta física isolada para um projeto em Projects/, inicializa o repositório Git local
    e a configuração do workspace. Permite integração opcional com o GitHub.
    
    Args:
        project_name (str): Nome desejado para o projeto/pasta.
        mode (str): O modo de trabalho, "local" ou "cloud". Se "cloud", tenta subir para repositório privado no GitHub.
    """
    try:
        # 1. Definir caminhos base portáteis
        script_dir = os.path.dirname(os.path.abspath(__file__))
        portable_root = os.path.dirname(script_dir)
        projects_root = os.path.join(portable_root, "Projects")
        
        if not os.path.exists(projects_root):
            os.makedirs(projects_root, exist_ok=True)
            
        # 2. Sanitizar nome da pasta do projeto
        safe_name = _sanitizar_nome_projeto(project_name)
        project_path = os.path.join(projects_root, safe_name)
        
        # Evitar sobrescrever pasta existente gerando sufixo numérico
        counter = 1
        original_safe_name = safe_name
        while os.path.exists(project_path):
            safe_name = f"{original_safe_name}_{counter}"
            project_path = os.path.join(projects_root, safe_name)
            counter += 1
            
        os.makedirs(project_path, exist_ok=True)
        
        # 3. Inicializar Git local
        subprocess.run(["git", "init"], cwd=project_path, capture_output=True, text=True)
        
        # Criar commit inicial vazio para ter uma branch main/master estável
        env = os.environ.copy()
        env["GIT_AUTHOR_NAME"] = "OpenCode"
        env["GIT_AUTHOR_EMAIL"] = "opencode@local.ai"
        env["GIT_COMMITTER_NAME"] = "OpenCode"
        env["GIT_COMMITTER_EMAIL"] = "opencode@local.ai"
        
        subprocess.run(["git", "commit", "--allow-empty", "-m", "Initial commit"], cwd=project_path, env=env, capture_output=True, text=True)
        
        # 4. Criar estrutura do Workspace
        ws_dir = os.path.join(project_path, ".opencode")
        os.makedirs(ws_dir, exist_ok=True)
        
        workspace_json = {
            "mode": mode if mode in ["local", "cloud", "disabled"] else "local",
            "limitGB": 10
        }
        
        with open(os.path.join(ws_dir, "workspace.json"), "w", encoding="utf-8") as f:
            json.dump(workspace_json, f, indent=2)
            
        # Criar um README.md básico
        readme_content = f"# {project_name.strip()}\n\nProjeto criado dinamicamente a partir do chat do OpenCode.\n"
        with open(os.path.join(project_path, "README.md"), "w", encoding="utf-8") as f:
            f.write(readme_content)
            
        subprocess.run(["git", "add", "README.md", ".opencode/workspace.json"], cwd=project_path, capture_output=True, text=True)
        subprocess.run(["git", "commit", "-m", "Setup inicial do projeto"], cwd=project_path, env=env, capture_output=True, text=True)
        
        # 5. Criar no GitHub se solicitado (modo cloud)
        github_status = "Apenas local"
        if mode == "cloud":
            # Verificar se gh CLI está disponível
            gh_check = shutil.which("gh")
            if gh_check:
                res = subprocess.run(["gh", "repo", "create", safe_name, "--private", "--source=.", "--push"], cwd=project_path, capture_output=True, text=True)
                if res.returncode == 0:
                    github_status = f"Criado com sucesso no GitHub como repositório privado: {safe_name}"
                else:
                    github_status = f"Falha ao criar repositório no GitHub (verifique autenticação 'gh auth login'). Mantido localmente."
                    # Fallback para modo local no workspace.json
                    workspace_json["mode"] = "local"
                    with open(os.path.join(ws_dir, "workspace.json"), "w", encoding="utf-8") as f:
                        json.dump(workspace_json, f, indent=2)
            else:
                github_status = "Aviso: CLI do GitHub ('gh') não encontrada. Mantido apenas local."
                workspace_json["mode"] = "local"
                with open(os.path.join(ws_dir, "workspace.json"), "w", encoding="utf-8") as f:
                    json.dump(workspace_json, f, indent=2)

        result_payload = {
            "status": "success",
            "project_name": safe_name,
            "path": project_path.replace("\\", "/"),
            "mode": workspace_json["mode"],
            "github": github_status
        }
        
        return json.dumps(result_payload, indent=2)
        
    except Exception as e:
        return json.dumps({
            "status": "error",
            "message": str(e)
        }, indent=2)

if __name__ == "__main__":
    mcp.run()
