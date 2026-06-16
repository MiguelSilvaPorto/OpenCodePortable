const fs = require('fs');
const path = require('path');

const home = process.argv[2] || process.cwd();
const configPath = path.join(home, 'config', 'opencode.jsonc');

const officeMcp = path.join(home, 'scripts', 'office_mcp.py').replace(/\\/g, '/');
const projectMcp = path.join(home, 'scripts', 'project_generator.py').replace(/\\/g, '/');

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

const defaultVoiceCfg = {
    endpoint: process.env.GROQ_API_KEY ? "https://api.groq.com/openai/v1" : "http://localhost:11434/v1",
    model: process.env.GROQ_API_KEY ? "llama-3.1-8b-instant" : "llama3.2"
};

if (process.env.GROQ_API_KEY) {
    defaultVoiceCfg.apiKey = process.env.GROQ_API_KEY;
    defaultVoiceCfg.apiKeyEnv = "GROQ_API_KEY";
    defaultVoiceCfg.sttEndpoint = "https://api.groq.com/openai/v1";
    defaultVoiceCfg.sttModel = "whisper-large-v3-turbo";
    defaultVoiceCfg.sttApiKeyEnv = "GROQ_API_KEY";
}

if (!cfg) {
    cfg = {
        $schema: "https://opencode.ai/config.json",
        plugin: [
            [
                "@renjfk/opencode-voice",
                defaultVoiceCfg
            ],
            "multitask",
            "multitask-tui.tsx",
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

    // Migrar plugin se GROQ_API_KEY estiver disponível
    if (process.env.GROQ_API_KEY && cfg.plugin && Array.isArray(cfg.plugin)) {
        let voicePlugin = cfg.plugin.find(p => Array.isArray(p) && p[0] === "@renjfk/opencode-voice");
        if (voicePlugin && voicePlugin[1]) {
            const voiceCfg = voicePlugin[1];
            if (!voiceCfg.apiKeyEnv || !voiceCfg.sttEndpoint) {
                voiceCfg.apiKeyEnv = "GROQ_API_KEY";
                voiceCfg.sttEndpoint = "https://api.groq.com/openai/v1";
                voiceCfg.sttModel = "whisper-large-v3-turbo";
                voiceCfg.sttApiKeyEnv = "GROQ_API_KEY";
            }
        }
    }
    // Migrar modelo antigo/descontinuado no config se existir
    if (cfg.plugin && Array.isArray(cfg.plugin)) {
        let voicePlugin = cfg.plugin.find(p => Array.isArray(p) && p[0] === "@renjfk/opencode-voice");
        if (voicePlugin && voicePlugin[1]) {
            const voiceCfg = voicePlugin[1];
            if (voiceCfg.model === "llama3-8b-8192") {
                voiceCfg.model = "llama-3.1-8b-instant";
            }
        }
    }
}

// Escrever de volta com indentação limpa e formato JSON correto
fs.writeFileSync(configPath, JSON.stringify(cfg, null, 4), 'utf8');
console.log('[CONFIG] Arquivo de configuracao atualizado com sucesso via Node.js.');
