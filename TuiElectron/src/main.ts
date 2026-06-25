import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import * as path from 'path';
import { spawn, execSync } from 'child_process';
import * as http from 'http';
import * as fs from 'fs';

let mainWindow: BrowserWindow | null = null;
let odSseConnection: http.ClientRequest | null = null;
let localServer: http.Server | null = null;
const OD_DAEMON_PORT = 63788;
const OD_DAEMON_URL = `http://127.0.0.1:${OD_DAEMON_PORT}`;
let localServerPort = 3456;

// ===== LOCAL SERVER FOR OPEN DESIGN PREVIEW =====
function startLocalServer() {
  if (localServer) return;
  try {
  const htmlPath = path.join(__dirname, '../src/renderer/index.html');
  const htmlContent = fs.readFileSync(htmlPath, 'utf8');

  // Inject browser detection script at the top of the HTML
  const browserScript = `<script>
    if (!window.electronAPI) {
      window.electronAPI = {
        minimize: () => {},
        maximize: () => {},
        close: () => {},
        executePrompt: async (msg, agent, model) => {
          const res = await fetch('/api/execute-prompt', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prompt: msg, agent, model: model || 'opencode-go/minimax-m3' })
          });
          return res.json();
        },
        openTerminal: async () => {},
        selectFolder: async () => null,
        getStatus: async () => {
          const res = await fetch('/api/status');
          return res.json();
        },
        getProviders: async () => {
          const res = await fetch('/api/providers');
          return res.json();
        },
        getModelsConfig: async () => {
          const res = await fetch('/api/models-config');
          return res.json();
        },
        connectProvider: async (id, key) => {
          const res = await fetch('/api/connect-provider', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id, key })
          });
          return res.json();
        },
        disconnectProvider: async (id) => {
          const res = await fetch('/api/disconnect-provider', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
          });
          return res.json();
        },
        odGetDaemonStatus: async () => {
          const res = await fetch('/api/od-status');
          return res.json();
        },
        odGetProjectFiles: async (projectId) => {
          const res = await fetch('/api/od-files/' + projectId);
          return res.json();
        },
        odReadFile: async (projectId, fileName) => {
          const res = await fetch('/api/od-file/' + projectId + '/' + encodeURIComponent(fileName));
          return res.json();
        },
        odWriteFile: async (projectId, fileName, content) => {
          const res = await fetch('/api/od-write-file', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ projectId, fileName, content })
          });
          return res.json();
        },
        odStartFileWatcher: async (projectId) => {
          const res = await fetch('/api/od-start-watcher/' + projectId);
          return res.json();
        },
        odStopFileWatcher: async () => {
          const res = await fetch('/api/od-stop-watcher');
          return res.json();
        },
        odCreateProject: async (name, linkedDir) => {
          const res = await fetch('/api/od-create-project', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, linkedDir })
          });
          return res.json();
        },
        onFileChanged: null,
      };
    }
  </script>`;

  const modifiedHtml = htmlContent.replace('<head>', '<head>' + browserScript);

  localServer = http.createServer(async (req, res) => {
    const url = new URL(req.url || '/', `http://localhost:${localServerPort}`);

    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

    // Serve index.html
    if (url.pathname === '/' || url.pathname === '/index.html') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(modifiedHtml);
      return;
    }

    // API routes
    const paths = getOpenCodePaths();

    if (url.pathname === '/api/status' && req.method === 'GET') {
      const exeExists = fs.existsSync(paths.bin);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ version: exeExists ? getLatestVersion() : null, exeExists, home: paths.home, projects: paths.projects }));
      return;
    }

    if (url.pathname === '/api/execute-prompt' && req.method === 'POST') {
      let body = '';
      req.on('data', (chunk) => { body += chunk; });
      req.on('end', () => {
        try {
          const { prompt, agent, model } = JSON.parse(body);
          if (!prompt) { res.writeHead(400, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: 'Empty prompt' })); return; }
          console.log(`[execute-prompt] agent=${agent} model=${model} promptLen=${prompt.length} bin=${paths.bin} cwd=${paths.projects}`);
          const args = ['run', prompt];
          if (model) args.push('--model', model);
          args.push('--agent', agent || 'composer', '--dangerously-skip-permissions', '--format', 'json');
          const child = spawn(paths.bin, args, {
            cwd: paths.projects, env: { ...process.env, OPENCODE_CONFIG: paths.config, OPENCODE_DISABLE_PROJECT_CONFIG: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
          });
          let stdout = '', stderr = '';
          const timeout = setTimeout(() => {
            try { child.kill(); } catch {}
            if (!res.writableEnded) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ stdout, stderr, code: -1, timeout: true })); }
          }, 180000);
          child.stdout?.on('data', (d) => { const s = d.toString(); stdout += s; });
          child.stderr?.on('data', (d) => { const s = d.toString(); stderr += s; });
          child.on('close', (code) => {
            clearTimeout(timeout);
            console.log(`[execute-prompt] done code=${code} stdoutLen=${stdout.length} stderrLen=${stderr.length}`);
            let text = '';
            try {
              const lines = stdout.split('\n').filter(l => l.trim());
              for (const line of lines) {
                try {
                  const ev = JSON.parse(line);
                  if (ev.type === 'text' && ev.part?.text) text += ev.part.text;
                } catch {}
              }
            } catch {}
            const cleanText = text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').trim();
            if (!res.writableEnded) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ response: cleanText, stdout, stderr, code })); }
          });
          child.on('error', (err) => {
            clearTimeout(timeout);
            console.log(`[execute-prompt] error: ${err.message}`);
            if (!res.writableEnded) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: err.message, stdout, stderr })); }
          });
        } catch (e: any) {
          console.log(`[execute-prompt] exception: ${e.message}`);
          res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: e.message }));
        }
      });
      return;
    }

    if (url.pathname === '/api/providers' && req.method === 'GET') {
      const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
      const connectedIds: string[] = [];
      try { if (fs.existsSync(authPath)) { const auth = JSON.parse(fs.readFileSync(authPath, 'utf8')); connectedIds.push(...Object.keys(auth)); } } catch {}
      const allProviders = [
        { id: 'opencode', name: 'OpenCode Zen', desc: 'Modelos curados pay-per-token', color: '#3ddc84' },
        { id: 'opencode-go', name: 'OpenCode Go', desc: 'Assinacao mensal premium', color: '#4a9eff' },
        { id: 'nvidia', name: 'NVIDIA', desc: 'build.nvidia.com', color: '#76b900' },
        { id: 'openrouter', name: 'OpenRouter', desc: 'Gateway multi-provedor', color: '#ff6b35' },
        { id: 'anthropic', name: 'Anthropic', desc: 'Claude models', color: '#d4a574' },
        { id: 'openai', name: 'OpenAI', desc: 'GPT-5, GPT-4', color: '#10a37f' },
        { id: 'groq', name: 'Groq', desc: 'Inferencia ultrarapida', color: '#f55036' },
        { id: 'deepseek', name: 'DeepSeek', desc: 'DeepSeek V4', color: '#4d6bfe' },
        { id: 'xai', name: 'xAI', desc: 'Grok models', color: '#1d9bf0' },
        { id: 'ollama', name: 'Ollama (local)', desc: 'Modelos locais', color: '#888' },
      ];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(allProviders.map(p => ({ ...p, connected: connectedIds.includes(p.id) }))));
      return;
    }

    if (url.pathname === '/api/models-config' && req.method === 'GET') {
      let config: any = {};
      try {
        if (fs.existsSync(paths.config)) {
          const raw = fs.readFileSync(paths.config, 'utf8');
          let clean = '', inString = false, esc = false;
          for (let i = 0; i < raw.length; i++) {
            const c = raw[i];
            if (esc) { clean += c; esc = false; continue; }
            if (inString) { if (c === '\\') esc = true; if (c === '"') inString = false; clean += c; continue; }
            if (c === '"') { inString = true; clean += c; continue; }
            if (c === '/' && raw[i + 1] === '/') { while (i < raw.length && raw[i] !== '\n') i++; clean += '\n'; continue; }
            if (c === '/' && raw[i + 1] === '*') { i += 2; while (i < raw.length && !(raw[i] === '*' && raw[i + 1] === '/')) i++; i++; continue; }
            clean += c;
          }
          config = JSON.parse(clean);
        }
      } catch {}
      let allModelLines: string[] = [];
      try {
        const output = execSync(`"${paths.bin}" models --pure`, { encoding: 'utf8', timeout: 15000, env: { ...process.env, OPENCODE_CONFIG: paths.config } });
        allModelLines = output.trim().split('\n').filter((l: string) => l.trim());
      } catch {}
      const excludePatterns = ['/flux', '/image', '/tts', '/voice', '/speaker', '/stt', '/whisper', '/embed', '/rerank', '/safety', '/pii', '/guard', '/esm', '/fold', '/cosmos', '/sparsedrive', '/streampetr', '/bevformer', '/glir', '/synthetic-video', '/detect', '/translate-4b', '/nv-embed', '/studiovoice', '/active-speaker', '/magpie-tts', '/riva-translate', '/nemotron-voice', '/nemotron-content-safety', '/nemotron-nano-9b-v2'];
      const providerMap: Record<string, any> = {};
      const providerNames: Record<string, string> = { 'opencode': 'OpenCode Zen', 'opencode-go': 'OpenCode Go', 'nvidia': 'NVIDIA', 'openrouter': 'OpenRouter' };
      for (const line of allModelLines) {
        const parts = line.split('/');
        if (parts.length < 2) continue;
        const providerId = parts[0];
        const modelId = parts.slice(1).join('/');
        const displayName = modelId.split('/').pop() || modelId;
        const fullName = line.trim();
        if (excludePatterns.some(p => fullName.toLowerCase().includes(p))) continue;
        if (displayName.match(/^[a-z0-9-]+-\d+[bB]-/)) continue;
        if (!providerMap[providerId]) providerMap[providerId] = { id: providerId, name: providerNames[providerId] || providerId, models: [] };
        providerMap[providerId].models.push({ id: fullName, name: displayName, isDefault: fullName === (config.model || ''), isSmall: fullName === (config.small_model || '') });
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ providers: Object.values(providerMap), defaultModel: config.model || '', smallModel: config.small_model || '' }));
      return;
    }

    if (url.pathname === '/api/connect-provider' && req.method === 'POST') {
      let body = '';
      req.on('data', (chunk) => { body += chunk; });
      req.on('end', () => {
        try {
          const { id, key } = JSON.parse(body);
          const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
          const authDir = path.dirname(authPath);
          if (!fs.existsSync(authDir)) fs.mkdirSync(authDir, { recursive: true });
          let auth: any = {};
          try { if (fs.existsSync(authPath)) auth = JSON.parse(fs.readFileSync(authPath, 'utf8')); } catch {}
          auth[id] = { type: 'api', key };
          fs.writeFileSync(authPath, JSON.stringify(auth, null, 2), 'utf8');
          res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ success: true }));
        } catch (e: any) { res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: e.message })); }
      });
      return;
    }

    if (url.pathname === '/api/disconnect-provider' && req.method === 'POST') {
      let body = '';
      req.on('data', (chunk) => { body += chunk; });
      req.on('end', () => {
        try {
          const { id } = JSON.parse(body);
          const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
          if (fs.existsSync(authPath)) {
            let auth: any = JSON.parse(fs.readFileSync(authPath, 'utf8'));
            delete auth[id];
            fs.writeFileSync(authPath, JSON.stringify(auth, null, 2), 'utf8');
          }
          res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ success: true }));
        } catch (e: any) { res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: e.message })); }
      });
      return;
    }

    // Open Design proxy routes
    if (url.pathname.startsWith('/api/od-status')) {
      http.get(`${OD_DAEMON_URL}/api/projects`, { timeout: 3000 }, (odRes) => {
        let data = ''; odRes.on('data', (c) => { data += c; });
        odRes.on('end', () => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(data); });
      }).on('error', (err) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ connected: false, error: err.message })); });
      return;
    }

    if (url.pathname.startsWith('/api/od-files/')) {
      const projectId = url.pathname.split('/')[3];
      http.get(`${OD_DAEMON_URL}/api/projects/${projectId}/files`, { timeout: 5000 }, (odRes) => {
        let data = ''; odRes.on('data', (c) => { data += c; });
        odRes.on('end', () => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(data); });
      }).on('error', (err) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: err.message })); });
      return;
    }

    if (url.pathname.startsWith('/api/od-file/')) {
      const parts = url.pathname.split('/');
      const projectId = parts[3];
      const fileName = decodeURIComponent(parts.slice(4).join('/'));
      http.get(`${OD_DAEMON_URL}/api/projects/${projectId}/files/${encodeURIComponent(fileName)}`, { timeout: 5000 }, (odRes) => {
        let data = ''; odRes.on('data', (c) => { data += c; });
        odRes.on('end', () => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(data); });
      }).on('error', (err) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: err.message })); });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  });

  localServer.listen(localServerPort, '127.0.0.1', () => {
    console.log(`Local server running at http://127.0.0.1:${localServerPort}`);
  });

  localServer.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      console.log(`Port ${localServerPort} in use, trying ${localServerPort + 1}`);
      localServer = null;
      localServerPort++;
      startLocalServer();
    }
  });
 } catch (err) {
   console.error('Failed to start local server:', err);
   localServer = null;
 }
}

function stopLocalServer() {
  if (localServer) { localServer.close(); localServer = null; }
}

function getOpenCodePaths() {
  const home = path.resolve(__dirname, '..', '..');
  return {
    home,
    bin: path.join(home, 'bin', 'opencode.exe'),
    data: path.join(home, 'data'),
    config: path.join(home, 'config', 'opencode.jsonc'),
    projects: path.join(home, 'Projects'),
  };
}

function getLatestVersion(): string {
  try {
    const binPath = getOpenCodePaths().bin;
    const result = execSync(`"${binPath}" --version`, { encoding: 'utf8', timeout: 5000 });
    const match = result.match(/(\d+\.\d+\.\d+)/);
    return match ? match[1] : 'unknown';
  } catch {
    return 'unknown';
  }
}

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0d0d0d',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, '../assets/icon.png'),
  });

  mainWindow.loadFile(path.join(__dirname, '../src/renderer/index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();
  startLocalServer();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

ipcMain.on('window-minimize', () => mainWindow?.minimize());
ipcMain.on('window-maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
});
ipcMain.on('window-close', () => mainWindow?.close());

ipcMain.handle('get-status', async () => {
  const paths = getOpenCodePaths();
  const fs = await import('fs');
  const exeExists = fs.existsSync(paths.bin);
  return {
    version: exeExists ? getLatestVersion() : null,
    exeExists,
    home: paths.home,
    projects: paths.projects,
  };
});

ipcMain.handle('execute-prompt', async (_event, prompt: string, agent?: string) => {
  const paths = getOpenCodePaths();
  if (!prompt || !prompt.trim()) return { error: 'Empty prompt' };

  const agentName = agent || 'composer';

  return new Promise((resolve) => {
    const child = spawn(paths.bin, ['run', prompt, '--agent', agentName, '--dangerously-skip-permissions'], {
      cwd: paths.projects,
      env: {
        ...process.env,
        OPENCODE_CONFIG: paths.config,
        OPENCODE_DISABLE_PROJECT_CONFIG: '1',
      },
      shell: true,
    });

    let stdout = '';
    let stderr = '';

    child.stdout?.on('data', (data: Buffer) => { stdout += data.toString(); });
    child.stderr?.on('data', (data: Buffer) => { stderr += data.toString(); });

    child.on('close', (code) => {
      resolve({ stdout, stderr, code });
    });

    child.on('error', (err) => {
      resolve({ error: err.message, stdout, stderr });
    });
  });
});

ipcMain.handle('open-terminal', async (_event, projectPath?: string) => {
  const paths = getOpenCodePaths();
  const targetDir = projectPath || paths.projects;
  const wtPath = process.env.LOCALAPPDATA
    ? path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WindowsApps', 'wt.exe')
    : 'wt.exe';

  try {
    spawn('powershell.exe', [
      '-NoProfile', '-ExecutionPolicy', 'Bypass',
      '-Command', `& '${paths.bin}' '${targetDir}'`,
    ], { shell: true, detached: true, stdio: 'ignore' }).unref();
    return { success: true };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('select-folder', async () => {
  if (!mainWindow) return null;
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory'],
    title: 'Selecionar Projeto',
  });
  if (result.canceled || result.filePaths.length === 0) return null;
  return result.filePaths[0];
});

ipcMain.handle('connect-provider', async (_event, providerId: string, apiKey: string) => {
  const fs = await import('fs');
  const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
  const authDir = path.dirname(authPath);
  if (!fs.existsSync(authDir)) fs.mkdirSync(authDir, { recursive: true });
  let auth: any = {};
  try {
    if (fs.existsSync(authPath)) auth = JSON.parse(fs.readFileSync(authPath, 'utf8'));
  } catch {}
  auth[providerId] = { type: 'api', key: apiKey };
  fs.writeFileSync(authPath, JSON.stringify(auth, null, 2), 'utf8');
  return { success: true };
});

ipcMain.handle('disconnect-provider', async (_event, providerId: string) => {
  const fs = await import('fs');
  const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
  if (!fs.existsSync(authPath)) return { success: true };
  let auth: any = {};
  try { auth = JSON.parse(fs.readFileSync(authPath, 'utf8')); } catch {}
  delete auth[providerId];
  fs.writeFileSync(authPath, JSON.stringify(auth, null, 2), 'utf8');
  return { success: true };
});

ipcMain.handle('get-providers', async () => {
  const paths = getOpenCodePaths();
  const fs = await import('fs');
  const authPath = path.join(process.env.USERPROFILE || '', '.local', 'share', 'opencode', 'auth.json');
  const connectedIds: string[] = [];
  try {
    if (fs.existsSync(authPath)) {
      const auth = JSON.parse(fs.readFileSync(authPath, 'utf8'));
      connectedIds.push(...Object.keys(auth));
    }
  } catch {}

  // All known OpenCode providers (70+)
  const allProviders = [
    // Built-in OpenCode providers
    { id: 'opencode', name: 'OpenCode Zen', desc: 'Modelos curados pay-per-token', color: '#3ddc84' },
    { id: 'opencode-go', name: 'OpenCode Go', desc: 'Assinacao mensal premium', color: '#4a9eff' },
    // Major providers
    { id: 'nvidia', name: 'NVIDIA', desc: 'build.nvidia.com — open-source', color: '#76b900' },
    { id: 'openrouter', name: 'OpenRouter', desc: 'Gateway multi-provedor', color: '#ff6b35' },
    { id: 'anthropic', name: 'Anthropic', desc: 'Claude models', color: '#d4a574' },
    { id: 'openai', name: 'OpenAI', desc: 'GPT-5, GPT-4, o1, o3', color: '#10a37f' },
    { id: 'google-vertex', name: 'Google Vertex AI', desc: 'Gemini via GCP', color: '#4285f4' },
    { id: 'google-generative-ai', name: 'Google AI', desc: 'Gemini models', color: '#4285f4' },
    { id: 'amazon-bedrock', name: 'Amazon Bedrock', desc: 'Modelos via AWS', color: '#ff9900' },
    { id: 'github-copilot', name: 'GitHub Copilot', desc: 'Assinatura Copilot', color: '#6e40c9' },
    { id: 'groq', name: 'Groq', desc: 'Inferencia ultrarapida', color: '#f55036' },
    { id: 'deepseek', name: 'DeepSeek', desc: 'DeepSeek V4 models', color: '#4d6bfe' },
    { id: 'xai', name: 'xAI', desc: 'Grok models', color: '#1d9bf0' },
    { id: 'mistralai', name: 'Mistral AI', desc: 'Mistral, Codestral', color: '#f7931e' },
    { id: 'cohere', name: 'Cohere', desc: 'Command models', color: '#39d98a' },
    { id: 'perplexity', name: 'Perplexity', desc: 'Sonar models', color: '#20b2aa' },
    { id: 'fireworks', name: 'Fireworks AI', desc: 'Open-source models', color: '#ff4500' },
    { id: 'together', name: 'Together AI', desc: 'Open-source models', color: '#6366f1' },
    { id: 'cerebras', name: 'Cerebras', desc: 'Inferencia ultrarapida', color: '#00b4d8' },
    { id: 'minimax', name: 'MiniMax', desc: 'MiniMax models', color: '#6366f1' },
    { id: 'z-ai', name: 'Zhipu AI', desc: 'GLM models', color: '#4a9eff' },
    { id: 'xiaomi', name: 'Xiaomi', desc: 'MiMo models', color: '#ff6900' },
    { id: 'moonshot', name: 'Moonshot AI', desc: 'Kimi models', color: '#6366f1' },
    { id: 'alibaba', name: 'Alibaba Cloud', desc: 'Qwen models', color: '#ff6a00' },
    { id: 'stepfun', name: 'StepFun', desc: 'Step models', color: '#6366f1' },
    { id: 'rekaai', name: 'Reka AI', desc: 'Reka models', color: '#6366f1' },
    { id: 'ibm-granite', name: 'IBM Granite', desc: 'Granite models', color: '#054ada' },
    { id: 'upstage', name: 'Upstage', desc: 'Solar models', color: '#6366f1' },
    // Local providers
    { id: 'ollama', name: 'Ollama (local)', desc: 'Modelos locais', color: '#888' },
    { id: 'lmstudio', name: 'LM Studio', desc: 'Modelos locais', color: '#888' },
    // Cloud providers
    { id: 'azure-openai', name: 'Azure OpenAI', desc: 'Azure models', color: '#0078d4' },
    { id: 'cloudflare', name: 'Cloudflare Workers AI', desc: 'Modelos na edge', color: '#f48120' },
    { id: 'huggingface', name: 'Hugging Face', desc: 'Inference Providers', color: '#ffd21e' },
    { id: 'deepinfra', name: 'Deep Infra', desc: 'Open-source models', color: '#6366f1' },
    { id: 'novita', name: 'Novita AI', desc: 'Open-source models', color: '#6366f1' },
    // Chinese providers
    { id: 'baidu', name: 'Baidu', desc: 'ERNIE models', color: '#2932e1' },
    { id: 'tencent', name: 'Tencent', desc: 'Hunyuan models', color: '#1da1f2' },
    { id: 'bytedance', name: 'ByteDance', desc: 'Seed models', color: '#000' },
    { id: 'sao10k', name: 'Sao10K', desc: 'Lunaris models', color: '#6366f1' },
    { id: 'nousresearch', name: 'NousResearch', desc: 'Hermes models', color: '#6366f1' },
    { id: 'deepcogito', name: 'DeepCogito', desc: 'Cogito models', color: '#6366f1' },
    // Enterprise
    { id: 'snowflake', name: 'Snowflake', desc: 'Cortex models', color: '#29b5e8' },
    { id: 'ovhcloud', name: 'OVHcloud', desc: 'AI Endpoints', color: '#000e9f' },
    { id: 'scaleway', name: 'Scaleway', desc: 'Open models', color: '#4169e1' },
    { id: 'stackit', name: 'STACKIT', desc: 'Open models', color: '#000' },
    { id: 'venice', name: 'Venice AI', desc: 'Open models', color: '#6366f1' },
    { id: 'zai', name: 'Z.AI', desc: 'Open models', color: '#6366f1' },
    // Additional
    { id: 'ai21', name: 'AI21', desc: 'Jamba models', color: '#000' },
    { id: 'inception', name: 'Inception', desc: 'Mercury models', color: '#6366f1' },
    { id: 'inflection', name: 'Inflection', desc: 'Pi models', color: '#6366f1' },
    { id: 'liquid', name: 'Liquid AI', desc: 'LFM models', color: '#6366f1' },
    { id: 'poolside', name: 'Poolside', desc: 'Laguna models', color: '#6366f1' },
    { id: 'prime-intellect', name: 'Prime Intellect', desc: 'Intellect models', color: '#6366f1' },
    { id: 'writer', name: 'Writer', desc: 'Palmyra models', color: '#000' },
    { id: 'morph', name: 'Morph', desc: 'Morph models', color: '#6366f1' },
    { id: 'relace', name: 'Relace', desc: 'Relace models', color: '#6366f1' },
    { id: 'arcee-ai', name: 'Arcee AI', desc: 'Arcee models', color: '#6366f1' },
    { id: 'essentialai', name: 'Essential AI', desc: 'Essential models', color: '#6366f1' },
    { id: 'anthracite-org', name: 'Anthracite', desc: 'Magnum models', color: '#6366f1' },
    { id: 'thrummer', name: 'TheDrummer', desc: 'Drummer models', color: '#6366f1' },
    { id: 'cognitivecomputations', name: 'Cognitive Computations', desc: 'Dolphin models', color: '#6366f1' },
    { id: 'gryphe', name: 'Gryphe', desc: 'Mythomax models', color: '#6366f1' },
    { id: 'undi95', name: 'Undi95', desc: 'REMM models', color: '#6366f1' },
    { id: 'kwaipilot', name: 'KwaiPilot', desc: 'Kat Coder', color: '#6366f1' },
    { id: 'nousresearch', name: 'NousResearch', desc: 'Hermes models', color: '#6366f1' },
    { id: 'switchpoint', name: 'Switchpoint', desc: 'Router models', color: '#6366f1' },
    { id: 'nex-agi', name: 'Nex AGI', desc: 'Nex models', color: '#6366f1' },
    { id: 'mancer', name: 'Mancer AI', desc: 'Weaver models', color: '#6366f1' },
    { id: 'perceptron', name: 'Perceptron', desc: 'Perceptron models', color: '#6366f1' },
    { id: 'inclusionai', name: 'Inclusion AI', desc: 'Ling models', color: '#6366f1' },
  ];

  return allProviders.map(p => ({
    ...p,
    connected: connectedIds.includes(p.id),
  }));
});

ipcMain.handle('get-models-config', async () => {
  const paths = getOpenCodePaths();
  const fs = await import('fs');
  let config: any = {};
  try {
    if (fs.existsSync(paths.config)) {
      const raw = fs.readFileSync(paths.config, 'utf8');
      let clean = '';
      let inString = false;
      let esc = false;
      for (let i = 0; i < raw.length; i++) {
        const c = raw[i];
        if (esc) { clean += c; esc = false; continue; }
        if (inString) {
          if (c === '\\') esc = true;
          if (c === '"') inString = false;
          clean += c;
          continue;
        }
        if (c === '"') { inString = true; clean += c; continue; }
        if (c === '/' && raw[i + 1] === '/') { while (i < raw.length && raw[i] !== '\n') i++; clean += '\n'; continue; }
        if (c === '/' && raw[i + 1] === '*') { i += 2; while (i < raw.length && !(raw[i] === '*' && raw[i + 1] === '/')) i++; i++; continue; }
        clean += c;
      }
      config = JSON.parse(clean);
    }
  } catch {}
  const defaultModel = config.model || '';
  const smallModel = config.small_model || '';

  // Get ALL models from opencode CLI
  let allModelLines: string[] = [];
  try {
    const { execSync } = require('child_process');
    const output = execSync(`"${paths.bin}" models --pure`, {
      encoding: 'utf8',
      timeout: 15000,
      env: { ...process.env, OPENCODE_CONFIG: paths.config },
    });
    allModelLines = output.trim().split('\n').filter((l: string) => l.trim());
  } catch {}

  // Filter out non-text models (image, audio, TTS, embedding, reranking, safety, etc.)
  const excludePatterns = [
    '/flux', '/image', '/tts', '/voice', '/speaker', '/stt', '/whisper',
    '/embed', '/rerank', '/safety', '/pii', '/guard', '/esm', '/fold',
    '/cosmos', '/sparsedrive', '/streampetr', '/bevformer', '/glir',
    '/synthetic-video', '/detect', '/translate-4b', '/nv-embed',
    '/studiovoice', '/active-speaker', '/magpie-tts', '/riva-translate',
    '/nemotron-voice', '/nemotron-content-safety', '/nemotron-nano-9b-v2',
  ];

  // Group models by provider
  const providerMap: Record<string, { id: string; name: string; models: any[] }> = {};
  const providerNames: Record<string, string> = {
    'opencode': 'OpenCode Zen',
    'opencode-go': 'OpenCode Go',
    'nvidia': 'NVIDIA',
    'openrouter': 'OpenRouter',
  };

  for (const line of allModelLines) {
    const parts = line.split('/');
    if (parts.length < 2) continue;
    const providerId = parts[0];
    const modelId = parts.slice(1).join('/');
    const displayName = modelId.split('/').pop() || modelId;
    const fullName = line.trim();

    // Skip non-text models
    if (excludePatterns.some(p => fullName.toLowerCase().includes(p))) continue;
    // Skip very small models (likely embeddings)
    if (displayName.match(/^[a-z0-9-]+-\d+[bB]-/)) continue;

    if (!providerMap[providerId]) {
      providerMap[providerId] = {
        id: providerId,
        name: providerNames[providerId] || providerId,
        models: [],
      };
    }
    providerMap[providerId].models.push({
      id: fullName,
      name: displayName,
      isDefault: fullName === defaultModel,
      isSmall: fullName === smallModel,
    });
  }

  // Also add any user-configured providers not in CLI output
  const providersConfig = config.provider || {};
  for (const [id, prov] of Object.entries(providersConfig) as any[]) {
    if (providerMap[id]) continue; // already have built-in models
    if (!prov.models) continue;
    const models: any[] = [];
    for (const [modelId, modelConf] of Object.entries(prov.models) as any[]) {
      const fullId = `${id}/${modelId}`;
      models.push({
        id: fullId,
        name: modelConf.name || modelId,
        isDefault: fullId === defaultModel,
        isSmall: fullId === smallModel,
      });
    }
    providerMap[id] = { id, name: prov.name || id, models };
  }

  const result = Object.values(providerMap);
  return { providers: result, defaultModel, smallModel };
});

// ===== OPEN DESIGN INTEGRATION =====

ipcMain.handle('od-get-daemon-status', async () => {
  return new Promise((resolve) => {
    http.get(`${OD_DAEMON_URL}/api/projects`, { timeout: 3000 }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ connected: true, projects: parsed.projects || [], port: OD_DAEMON_PORT });
        } catch {
          resolve({ connected: false, error: 'Invalid response' });
        }
      });
    }).on('error', (err) => {
      resolve({ connected: false, error: err.message });
    });
  });
});

ipcMain.handle('od-get-project-files', async (_event, projectId: string) => {
  return new Promise((resolve) => {
    http.get(`${OD_DAEMON_URL}/api/projects/${projectId}/files`, { timeout: 5000 }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ error: 'Invalid response' }); }
      });
    }).on('error', (err) => {
      resolve({ error: err.message });
    });
  });
});

ipcMain.handle('od-read-file', async (_event, projectId: string, fileName: string) => {
  return new Promise((resolve) => {
    http.get(`${OD_DAEMON_URL}/api/projects/${projectId}/files/${encodeURIComponent(fileName)}`, { timeout: 5000 }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ error: 'Invalid response' }); }
      });
    }).on('error', (err) => {
      resolve({ error: err.message });
    });
  });
});

ipcMain.handle('od-write-file', async (_event, projectId: string, fileName: string, content: string) => {
  return new Promise((resolve) => {
    const postData = JSON.stringify({ content });
    const req = http.request(`${OD_DAEMON_URL}/api/projects/${projectId}/files/${encodeURIComponent(fileName)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(postData) },
      timeout: 5000,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ success: res.statusCode === 200 }); }
      });
    });
    req.on('error', (err) => { resolve({ error: err.message }); });
    req.write(postData);
    req.end();
  });
});

ipcMain.handle('od-start-file-watcher', async (_event, projectId: string) => {
  if (odSseConnection) { odSseConnection.destroy(); odSseConnection = null; }

  return new Promise((resolve) => {
    odSseConnection = http.get(`${OD_DAEMON_URL}/api/projects/${projectId}/events`, { timeout: 30000 }, (res) => {
      let buffer = '';
      res.on('data', (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const event = JSON.parse(line.slice(6));
              mainWindow?.webContents.send('od-file-changed', event);
            } catch {}
          }
        }
      });
      res.on('end', () => { odSseConnection = null; });
      resolve({ success: true });
    });
    odSseConnection.on('error', (err) => {
      odSseConnection = null;
      resolve({ success: false, error: err.message });
    });
  });
});

ipcMain.handle('od-stop-file-watcher', async () => {
  if (odSseConnection) { odSseConnection.destroy(); odSseConnection = null; }
  return { success: true };
});

ipcMain.handle('od-create-project', async (_event, name: string, linkedDir?: string) => {
  return new Promise((resolve) => {
    const postData = JSON.stringify({ name, linkedDir });
    const req = http.request(`${OD_DAEMON_URL}/api/projects`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(postData) },
      timeout: 5000,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ error: 'Invalid response' }); }
      });
    });
    req.on('error', (err) => { resolve({ error: err.message }); });
    req.write(postData);
    req.end();
  });
});

// ===== LOCAL SERVER CONTROLS =====
ipcMain.handle('start-local-server', async () => {
  try {
    startLocalServer();
    return { success: true, port: localServerPort, url: `http://127.0.0.1:${localServerPort}` };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('stop-local-server', async () => {
  stopLocalServer();
  return { success: true };
});

ipcMain.handle('get-local-server-status', async () => {
  return { running: localServer !== null, port: localServerPort, url: `http://127.0.0.1:${localServerPort}` };
});
