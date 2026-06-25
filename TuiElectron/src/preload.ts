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
  connectProvider: (id: string, key: string) => ipcRenderer.invoke('connect-provider', id, key),
  disconnectProvider: (id: string) => ipcRenderer.invoke('disconnect-provider', id),

  // Open Design integration
  odGetDaemonStatus: () => ipcRenderer.invoke('od-get-daemon-status'),
  odGetProjectFiles: (projectId: string) => ipcRenderer.invoke('od-get-project-files', projectId),
  odReadFile: (projectId: string, fileName: string) => ipcRenderer.invoke('od-read-file', projectId, fileName),
  odWriteFile: (projectId: string, fileName: string, content: string) => ipcRenderer.invoke('od-write-file', projectId, fileName, content),
  odStartFileWatcher: (projectId: string) => ipcRenderer.invoke('od-start-file-watcher', projectId),
  odStopFileWatcher: () => ipcRenderer.invoke('od-stop-file-watcher'),
  odCreateProject: (name: string, linkedDir?: string) => ipcRenderer.invoke('od-create-project', name, linkedDir),
  onFileChanged: (callback: (event: any) => void) => ipcRenderer.on('od-file-changed', (_event, data) => callback(data)),

  // Local server for preview
  startLocalServer: () => ipcRenderer.invoke('start-local-server'),
  stopLocalServer: () => ipcRenderer.invoke('stop-local-server'),
  getLocalServerStatus: () => ipcRenderer.invoke('get-local-server-status'),
});
