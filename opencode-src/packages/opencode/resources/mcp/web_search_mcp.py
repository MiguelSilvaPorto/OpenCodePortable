"""
web_search_mcp.py - Servidor MCP para busca web
Fornece ferramenta web_search para pesquisar na internet.
"""

import sys
import traceback

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("WebSearch", instructions="""
Servidor de busca web. Use web_search() para pesquisar informacoes na internet.
Os resultados incluem titulo, snippet e URL.
""")

@mcp.tool()
def web_search(query: str, max_results: int = 5) -> str:
    """
    Realiza uma busca na web e retorna resultados com titulo, descricao e URL.

    QUANDO USAR:
    - Quando precisar de informacoes atualizadas da internet
    - Para buscar modelos de documentos, exemplos ou templates
    - Para pesquisar dados publicos, estatisticas ou referencias
    - Para encontrar documentacao, guias ou tutoriais

    PARAMETROS:
    - query (str, obrigatorio): Termo de busca. Quanto mais especifico, melhores os resultados.
      Exemplos: "modelo de contrato prestacao de servicos Word",
                "dados economicos Brasil 2026",
                "formato ABNT documentos"

    - max_results (int, opcional): Numero maximo de resultados (1-20). Default: 5.

    RETORNO:
    - Lista formatada com resultados, cada um contendo:
      - Titulo
      - Snippet (descricao resumida)
      - URL
    - Ou mensagem "Nenhum resultado encontrado." se a busca nao retornar nada.

    IMPORTANTE:
    - A busca e feita via DuckDuckGo (anonimo, sem necessidade de API key).
    - Resultados podem variar em relevancia — use queries especificas.
    - Nao e possivel acessar paginas completas, apenas snippets.
    - Para acessar paginas completas, use a ferramenta webfetch do opencode.

    EXEMPLO DE USO:
        web_search(query="modelo de ata de reuniao Word", max_results=3)
        # Retorna:
        # Resultado 1:
        # Titulo: Modelo de Ata de Reuniao - Word
        # Snippet: Baixe modelo gratuito de ata de reuniao em formato Word...
        # URL: https://exemplo.com/modelo-ata
    """
    try:
        from ddgs import DDGS
    except ImportError:
        from duckduckgo_search import DDGS

    try:
        results = []
        with DDGS() as ddgs:
            for i, r in enumerate(ddgs.text(query, max_results=max_results), 1):
                results.append(
                    f"Resultado {i}:\n"
                    f"Titulo: {r.get('title', '')}\n"
                    f"Snippet: {r.get('body', '')}\n"
                    f"URL: {r.get('href', '')}\n"
                )

        if not results:
            return "Nenhum resultado encontrado."

        return "\n".join(results)
    except Exception as e:
        return f"Erro na busca web: {str(e)[:300]}"


if __name__ == "__main__":
    mcp.run(transport="stdio")
