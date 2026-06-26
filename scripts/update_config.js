const fs = require('fs');
const path = require('path');

const home = process.argv[2] || process.cwd();
const configPath = path.join(home, 'config', 'opencode.jsonc');

const officeMcp = path.join(home, 'scripts', 'office_mcp.py').replace(/\\/g, '/');
const projectMcp = path.join(home, 'scripts', 'project_generator.py').replace(/\\/g, '/');
const brainMcp = path.join(home, '.brain', 'scripts', 'brain_mcp.py').replace(/\\/g, '/');
const skillMcp = path.join(home, '.brain', 'scripts', 'skill_mcp.py').replace(/\\/g, '/');
const webSearchMcp = path.join(home, 'scripts', 'web_search_mcp.py').replace(/\\/g, '/');

let cfg = null;
let fileExists = false;

try {
    if (fs.existsSync(configPath)) {
        fileExists = true;
        const raw = fs.readFileSync(configPath, 'utf8');
        // Remover comentários JSONC de forma segura (preservando URLs)
        const jsonClean = raw.replace(/\\"|"(?:\\"|[^"])*"|(\/\/.*|\/\*[\s\S]*?\*\/)/g, (m, g) => g ? "" : m);
        cfg = JSON.parse(jsonClean);
    }
} catch (e) {
    console.warn(`[CONFIG] Falha ao ler ou analisar config existente: ${e.message}. Criando nova.`);
}



if (!cfg) {
    cfg = {
        $schema: "https://opencode.ai/config.json",
        plugin: [
            "workspace-tui.tsx",
            "auto-switch-mode.ts"
        ],
        mcp: {
            "office-mcp": {
                type: "local",
                command: ["python", officeMcp],
                enabled: true
            },
            "project-mcp": {
                type: "local",
                command: ["python", projectMcp],
                enabled: true
            },
            "brain-mcp": {
                type: "local",
                command: ["python", brainMcp],
                enabled: true
            },
            "skill-mcp": {
                type: "local",
                command: ["python", skillMcp],
                enabled: true
            },
            "web-search-mcp": {
                type: "local",
                command: ["python", webSearchMcp],
                enabled: true
            }
        }
    };
} else {
    // Garantir mcp e caminhos corretos
    if (!cfg.mcp) cfg.mcp = {};
    
    if (!cfg.mcp["office-mcp"]) {
        cfg.mcp["office-mcp"] = { type: "local", command: ["python", officeMcp], enabled: true };
    } else {
        cfg.mcp["office-mcp"].command = ["python", officeMcp];
    }

    if (!cfg.mcp["project-mcp"]) {
        cfg.mcp["project-mcp"] = { type: "local", command: ["python", projectMcp], enabled: true };
    } else {
        cfg.mcp["project-mcp"].command = ["python", projectMcp];
    }

    if (!cfg.mcp["brain-mcp"]) {
        cfg.mcp["brain-mcp"] = { type: "local", command: ["python", brainMcp], enabled: true };
    } else {
        cfg.mcp["brain-mcp"].command = ["python", brainMcp];
    }

    if (!cfg.mcp["skill-mcp"]) {
        cfg.mcp["skill-mcp"] = { type: "local", command: ["python", skillMcp], enabled: true };
    } else {
        cfg.mcp["skill-mcp"].command = ["python", skillMcp];
    }

    if (!cfg.mcp["web-search-mcp"]) {
        cfg.mcp["web-search-mcp"] = { type: "local", command: ["python", webSearchMcp], enabled: true };
    } else {
        cfg.mcp["web-search-mcp"].command = ["python", webSearchMcp];
    }


}

// Escrever de volta com indentação limpa e formato JSON correto
fs.writeFileSync(configPath, JSON.stringify(cfg, null, 4), 'utf8');
console.log('[CONFIG] Arquivo de configuracao atualizado com sucesso via Node.js.');
