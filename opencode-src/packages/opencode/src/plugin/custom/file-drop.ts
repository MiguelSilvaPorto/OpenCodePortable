import type { Plugin } from "@opencode-ai/plugin"

const recentFiles: string[] = []

function extrairCaminhos(texto: string): string[] {
  const padrao = /[a-zA-Z]:\\(?:[^\\\s"]+\\)*[^\\\s"]*\.[a-zA-Z]{3,4}/g
  const encontrados = texto.match(padrao)
  if (!encontrados) return []

  const caminhos = encontrados.map(p => p.replace(/["']$/, ""))
  return [...new Set(caminhos)]
}

async function lerArquivo(caminho: string, $: any): Promise<string> {
  const ext = caminho.toLowerCase().split(".").pop()

  if (ext === "docx") {
    return (await $`python -c @"
import sys, json
from docx import Document
doc = Document('${caminho.replace(/'/g, "''")}')
print(json.dumps([p.text for p in doc.paragraphs if p.text.strip()], ensure_ascii=False)[:5000])
"`) as unknown as string
  }

  if (ext === "xlsx" || ext === "xlsm") {
    return (await $`python -c @"
import json
from openpyxl import load_workbook
wb = load_workbook('${caminho.replace(/'/g, "''")}', read_only=True, data_only=True)
info = {s: sum(1 for _ in wb[s].iter_rows()) for s in wb.sheetnames}
print(json.dumps(info, ensure_ascii=False)[:3000])
"`) as unknown as string
  }

  if (ext === "pptx") {
    return (await $`python -c @"
import json
from pptx import Presentation
prs = Presentation('${caminho.replace(/'/g, "''")}')
slides = []
for i, slide in enumerate(prs.slides, 1):
    texts = [s.text for s in slide.shapes if s.has_text_frame]
    slides.append({'slide': i, 'textos': texts})
print(json.dumps(slides[:10], ensure_ascii=False)[:3000])
"`) as unknown as string
  }

  if (ext === "pdf") {
    return (await $`python -c @"
import json
import fitz
doc = fitz.open('${caminho.replace(/'/g, "''")}')
paginas = []
for i in range(min(5, doc.page_count)):
    paginas.append({'pagina': i+1, 'texto': doc[i].get_text('text').strip()[:500]})
print(json.dumps({'total_paginas': doc.page_count, 'amostra': paginas}, ensure_ascii=False)[:5000])
doc.close()
"`) as unknown as string
  }

  if (ext === "txt" || ext === "csv" || ext === "md" || ext === "json") {
    return (await $`Get-Content -Path '${caminho.replace(/'/g, "''")}' -Encoding UTF8 -TotalCount 100`) as unknown as string
  }

  const imagens = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "svg", "ico"]
  if (imagens.includes(ext)) {
    const info = (await $`Get-Item -LiteralPath '${caminho.replace(/'/g, "''")}' | Select-Object Length, LastWriteTime | Format-Table -HideTableHeaders | Out-String`).toString().trim()
    return `[IMAGEM] ${ext.toUpperCase()} - ${info} | O modelo NAO pode ler imagens. Peça ao usuario para descrever o conteudo da imagem se necessario.`
  }

  return `[FORMATO NAO SUPORTADO] .${ext} - Apenas o caminho do arquivo foi registrado. Use as ferramentas MCP disponiveis se quiser processa-lo.`
}

async function lerPasta(caminho: string, $: any): Promise<string> {
  const itens = await $`Get-ChildItem -Path '${caminho.replace(/'/g, "''")}' | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String`
  return itens as unknown as string || "Pasta vazia."
}

export const FileDropPlugin: Plugin = async ({ client, $ }) => {
  return {
    "tui.prompt.append": async (input, output) => {
      const texto = output.text || input.text || ""
      if (!texto || texto.length < 3) return

      const caminhos = extrairCaminhos(texto)
      if (caminhos.length === 0) return

      let anexo = "\n\n---\n**📎 Arquivos detectados:**\n"
      let textoModificado = texto
      let idx = 0

      for (const caminho of caminhos) {
        const existe = await $`Test-Path -LiteralPath '${caminho.replace(/'/g, "''")}'`
        if (!(existe as unknown as boolean)) continue

        recentFiles.unshift(caminho)
        if (recentFiles.length > 10) recentFiles.length = 10
        idx++

        const ehPasta = await $`Test-Path -LiteralPath '${caminho.replace(/'/g, "''")}' -PathType Container`

        // Substitui o caminho bruto no texto por um indice cego
        // para impedir que o modelo tente usar read() no caminho
        textoModificado = textoModificado.replace(caminho, `[arquivo_${idx}]`)

        if (ehPasta as unknown as boolean) {
          const conteudo = await lerPasta(caminho, $)
          anexo += `[arquivo_${idx}] 📁 Pasta: ${caminho}\n\`\`\`\n${conteudo}\n\`\`\`\n\n`
        } else {
          const conteudo = await lerArquivo(caminho, $)
          anexo += `[arquivo_${idx}] 📄 Arquivo: ${caminho}\n\`\`\`\n${conteudo.trim()}\n\`\`\`\n\n`
        }
      }

      output.text = textoModificado + anexo
    }
  }
}
