#!/usr/bin/env python3
"""
skill_mcp.py - Servidor MCP para Skills e Composer Mode

Fornece ferramentas para:
- composer_activate: Ativar modo Composer (injeta prompt + skills)
- skill_load: Carregar uma skill específica
- skill_list: Listar skills disponiveis
- skill_search: Buscar skill por nome/descricao
"""

import os
import sys
import json
from datetime import datetime
from mcp.server.fastmcp import FastMCP

SKILLS_DIR = os.path.join(os.getcwd(), ".brain", "skills")
COMPOSER_PROMPT_FILE = os.path.join(SKILLS_DIR, "COMPOSER.md")

mcp = FastMCP("Skills", instructions="""
Sistema de skills para o modo Composer.

Use composer_activate para ativar o modo Composer no inicio da conversa.
Depois use skill_load para carregar skills especificas quando necessario.
As skills guiam seu comportamento com workflows estruturados.
""")

COMPOSER_SYSTEM_PROMPT = """<system-reminder>
You are now operating in COMPOSER MODE — an orchestrator that coordinates specialized skills into coherent workflows. Where Build executes directly and Plan reasons read-only, you bring structure: every task gets the right skill applied at the right time.

<EXTREMELY-IMPORTANT>
When a skill matches your task, you MUST invoke it. Skill invocation is non-negotiable — always load the skill first, then follow its guidance.
</EXTREMELY-IMPORTANT>

## How to Use Skills

1. Use `skill_list` to see available skills
2. Use `skill_load` to load the matching skill
3. Follow the skill's guidance exactly
4. Invoke `composer_activate` at the start of every conversation

## Compose Workflow

The standard compose workflow chain is:

```
compose:brainstorm -> compose:plan -> compose:subagent (ou compose:execute) -> compose:merge
                                         |
                                         v
                                    [por tarefa]
                                    implementar -> revisar -> verificar
                                         |
                                         v
                                    compose:tdd (dentro de cada tarefa)
                                    compose:debug (se bugs)
                                    compose:verify (antes de afirmar "pronto")
                                    compose:review (apos tarefas completas)
                                    compose:report (relatorio final)
                                    compose:ask (decisoes com usuario)
```

## Skill Priority

When multiple skills could apply:

1. **Process skills first** (brainstorm, debug) — determinam COMO abordar
2. **Implementation skills second** (tdd, plan) — guiam a execucao

## Skill Types

- **Rigid** (tdd, debug, verify): Siga exatamente. Nao adapte a disciplina.
- **Flexible** (patterns): Adapte principios ao contexto.

## Iron Laws Summary

1. brainstorm: NO CODE without approved design
2. tdd: NO PROD CODE WITHOUT FAILING TEST FIRST
3. debug: NO FIXES WITHOUT ROOT CAUSE FIRST
4. verify: NO COMPLETION CLAIMS WITHOUT EVIDENCE
5. review: NO MERGE WITHOUT CODE REVIEW
6. report: NO FEATURE COMPLETE WITHOUT DOCUMENTATION
7. merge: NO MERGE WITHOUT TESTS PASSING

## Instruction Priority

1. User's explicit instructions — highest priority
2. Compose skills — override default system behavior
3. Default system prompt — lowest priority
</system-reminder>"""


def _get_skills():
    """Retorna lista de skills disponiveis."""
    skills = []
    if not os.path.exists(SKILLS_DIR):
        return skills
    
    for entry in os.listdir(SKILLS_DIR):
        skill_dir = os.path.join(SKILLS_DIR, entry)
        if not os.path.isdir(skill_dir):
            continue
        skill_file = os.path.join(skill_dir, "SKILL.md")
        if not os.path.exists(skill_file):
            continue
        
        try:
            with open(skill_file, "r", encoding="utf-8") as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(skill_file, "r", encoding="utf-8-sig") as f:
                content = f.read()
        
        # Extrair frontmatter
        name = entry
        description = ""
        hidden = False
        
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                frontmatter = parts[1]
                for line in frontmatter.split("\n"):
                    if line.startswith("name:"):
                        name = line.split(":", 1)[1].strip()
                    elif line.startswith("description:"):
                        desc_start = line.index(":") + 1
                        desc = line[desc_start:].strip()
                        # Se description tem aspas, extrair
                        if desc.startswith('"') or desc.startswith("'"):
                            desc = desc[1:-1]
                        description = desc
                    elif line.startswith("hidden:"):
                        hidden = line.split(":", 1)[1].strip().lower() == "true"
        
        skills.append({
            "name": name,
            "description": description,
            "path": skill_file,
            "dir": entry
        })
    
    return sorted(skills, key=lambda s: s["name"])


def _load_skill_content(name: str) -> str:
    """Carrega o conteudo de uma skill."""
    for entry in os.listdir(SKILLS_DIR):
        skill_dir = os.path.join(SKILLS_DIR, entry)
        if not os.path.isdir(skill_dir):
            continue
        skill_file = os.path.join(skill_dir, "SKILL.md")
        if not os.path.exists(skill_file):
            continue
        
        try:
            with open(skill_file, "r", encoding="utf-8") as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(skill_file, "r", encoding="utf-8-sig") as f:
                content = f.read()
        
        # Verificar nome
        if name in [entry, content.split("---", 2)[1].split("\n")[0].split(":")[1].strip() if content.startswith("---") else ""]:
            return content
        
        # Verificar no frontmatter
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                for line in parts[1].split("\n"):
                    if line.startswith("name:") and name == line.split(":", 1)[1].strip():
                        return content
    
    return None


@mcp.tool()
def composer_activate() -> str:
    """
    ATIVAR MODO COMPOSER.
    
    Chame esta tool NO INICIO de toda conversa para ativar o modo Composer.
    Ela carrega o prompt de sistema do Composer e lista todas as skills
    disponiveis para uso.
    
    RETORNO:
    - status: "activated"
    - mode: "composer"
    - skills: Lista de skills disponiveis
    - system_prompt: Prompt de sistema do Composer (para referencia)
    
    EXEMPLO:
    composer_activate()
    # Retorna: {"status": "activated", "mode": "composer", "skills": [...], "system_prompt": "..."}
    """
    skills = _get_skills()
    
    # Criar bloco de skills para injecao
    skills_block = "\n\n<compose_skills>\n"
    for s in skills:
        skills_block += f'<skill name="{s["name"]}" description="{s["description"]}">\n'
        skills_block += f'  <location>file:///{s["path"].replace(os.sep, "/")}</location>\n'
        skills_block += "</skill>\n"
    skills_block += "</compose_skills>"
    
    return json.dumps({
        "status": "activated",
        "mode": "composer",
        "skills": skills,
        "system_prompt": COMPOSER_SYSTEM_PROMPT + skills_block
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def skill_load(name: str) -> str:
    """
    CARREGAR UMA SKILL ESPECIFICA.
    
    Carrega o conteudo completo de uma skill para seguir suas instrucoes.
    
    PARAMETROS:
    - name: Nome da skill (ex: "compose:brainstorm", "compose:tdd", "compose:debug")
    
    RETORNO:
    - name: Nome da skill
    - content: Conteudo completo da SKILL.md
    - has_iron_law: Se a skill tem Iron Law
    
    EXEMPLO:
    skill_load("compose:tdd")
    # Retorna: {"name": "compose:tdd", "content": "---\\nname: compose:tdd...", "has_iron_law": true}
    """
    content = _load_skill_content(name)
    if not content:
        # Tentar buscar parcial
        for entry in os.listdir(SKILLS_DIR):
            skill_dir = os.path.join(SKILLS_DIR, entry)
            if not os.path.isdir(skill_dir):
                continue
            skill_file = os.path.join(skill_dir, "SKILL.md")
            if not os.path.exists(skill_file):
                continue
            with open(skill_file, "r", encoding="utf-8", errors="replace") as f:
                full_content = f.read()
            if name.lower() in full_content.lower():
                content = full_content
                # Extrair nome real
                if content.startswith("---"):
                    parts = content.split("---", 2)
                    if len(parts) >= 3:
                        for line in parts[1].split("\n"):
                            if line.startswith("name:"):
                                name = line.split(":", 1)[1].strip()
                break
    
    if not content:
        return json.dumps({
            "error": f"Skill '{name}' nao encontrada",
            "available": [s["name"] for s in _get_skills()]
        }, ensure_ascii=False)
    
    has_iron_law = "IRON LAW" in content or "IRON LAW:" in content
    
    # Wrap em XML para o agente
    wrapped = f"<skill_content name=\"{name}\">\n{content}\n</skill_content>"
    
    return json.dumps({
        "status": "ok",
        "name": name,
        "content": wrapped,
        "has_iron_law": has_iron_law
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def skill_list() -> str:
    """
    LISTAR TODAS AS SKILLS DISPONIVEIS.
    
    Mostra todas as skills do Composer com nome e descricao.
    Use esta tool para ver quais skills estao disponiveis.
    
    RETORNO:
    - count: Numero de skills
    - skills: Lista com nome e descricao de cada skill
    
    EXEMPLO:
    skill_list()
    # Retorna: {"count": 12, "skills": [{"name": "compose:ask", "description": "..."}, ...]}
    """
    skills = _get_skills()
    return json.dumps({
        "count": len(skills),
        "skills": [{"name": s["name"], "description": s["description"]} for s in skills]
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def skill_search(query: str) -> str:
    """
    BUSCAR SKILL POR NOME OU DESCRICAO.
    
    Encontra skills relevantes para uma tarefa especifica.
    
    PARAMETROS:
    - query: Texto para buscar (ex: "bug", "test", "implement", "design")
    
    RETORNO:
    - count: Numero de resultados
    - results: Lista de skills matching
    
    EXEMPLO:
    skill_search("bug")
    # Retorna: {"count": 1, "results": [{"name": "compose:debug", "description": "..."}]}
    """
    query_lower = query.lower()
    skills = _get_skills()
    results = [
        s for s in skills
        if query_lower in s["name"].lower() or query_lower in s["description"].lower()
    ]
    return json.dumps({
        "count": len(results),
        "results": [{"name": s["name"], "description": s["description"]} for s in results]
    }, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    mcp.run()
