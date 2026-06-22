import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import * as path from 'path';
import { spawn, execSync } from 'child_process';

let mainWindow: BrowserWindow | null = null;

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

app.whenReady().then(createWindow);

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
  return connectedIds;
});

ipcMain.handle('get-models-config', async () => {
  const paths = getOpenCodePaths();
  const fs = await import('fs');
  let config: any = {};
  try {
    if (fs.existsSync(paths.config)) {
      let raw = fs.readFileSync(paths.config, 'utf8');
      raw = raw.replace(/\/\/.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '');
      config = JSON.parse(raw);
    }
  } catch {}
  const defaultModel = config.model || '';
  const smallModel = config.small_model || '';
  const providersConfig = config.provider || {};
  const result: any[] = [];
  for (const [id, prov] of Object.entries(providersConfig) as any[]) {
    const models: any[] = [];
    if (prov.models) {
      for (const [modelId, modelConf] of Object.entries(prov.models) as any[]) {
        models.push({
          id: `${id}/${modelId}`,
          name: modelConf.name || modelId,
          isDefault: `${id}/${modelId}` === defaultModel,
          isSmall: `${id}/${modelId}` === smallModel,
        });
      }
    }
    result.push({
      id,
      name: prov.name || id,
      models,
    });
  }
  return { providers: result, defaultModel, smallModel };
});
