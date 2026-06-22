import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  minimize: () => ipcRenderer.send('window-minimize'),
  maximize: () => ipcRenderer.send('window-maximize'),
  close: () => ipcRenderer.send('window-close'),

  executePrompt: (prompt: string, agent?: string) => ipcRenderer.invoke('execute-prompt', prompt, agent),
  openTerminal: (projectPath?: string) => ipcRenderer.invoke('open-terminal', projectPath),
  getStatus: () => ipcRenderer.invoke('get-status'),
  selectFolder: () => ipcRenderer.invoke('select-folder'),
  getProviders: () => ipcRenderer.invoke('get-providers'),
  getModelsConfig: () => ipcRenderer.invoke('get-models-config'),
});
