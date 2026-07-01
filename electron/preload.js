// preload bridge for renderer -> main IPC
// exposes `window.host` via contextBridge (contextIsolation:true, sandbox:true)

const { contextBridge, ipcRenderer } = require('electron');

let boot;
try {
  boot = ipcRenderer.sendSync('host:boot');
}
catch (e) {
  console.error('preload: host:boot failed', e);
  boot = { platform: 'unknown', isDebug: false };
}

contextBridge.exposeInMainWorld('host', {
  platform: boot.platform,
  isDebug: !!boot.isDebug,

  settings: {
    read:  ()     => ipcRenderer.sendSync('host:settings:read'),
    write: (data) => ipcRenderer.sendSync('host:settings:write', data),
  },
  profile: {
    read:   ()     => ipcRenderer.sendSync('host:profile:read'),
    write:  (data) => ipcRenderer.sendSync('host:profile:write', data),
    exists: ()     => ipcRenderer.sendSync('host:profile:exists'),
  },
  save: {
    read:      (slotID)       => ipcRenderer.sendSync('host:save:read', slotID),
    write:     (slotID, data) => ipcRenderer.sendSync('host:save:write', slotID, data),
    exists:    (slotID)       => ipcRenderer.sendSync('host:save:exists', slotID),
    readMeta:  (slotID)       => ipcRenderer.sendSync('host:save:readMeta', slotID),
    writeMeta: (slotID, data) => ipcRenderer.sendSync('host:save:writeMeta', slotID, data),
    delete:    (slotID)       => ipcRenderer.sendSync('host:save:delete', slotID),
  },
  consoleHistory: {
    read:   ()     => ipcRenderer.sendSync('host:console:read'),
    write:  (data) => ipcRenderer.sendSync('host:console:write', data),
    exists: ()     => ipcRenderer.sendSync('host:console:exists'),
  },
  log: {
    append: (line) => ipcRenderer.sendSync('host:log:append', line),
  },
  assets: {
    listSounds: () => ipcRenderer.sendSync('host:assets:listSounds'),
  },
  mods: {
    list:       () => ipcRenderer.sendSync('host:mods:list'),
    rescan:     () => ipcRenderer.sendSync('host:mods:rescan'),
    openFolder: () => ipcRenderer.sendSync('host:mods:openFolder'),
  },
  shell: {
    openExternal: (url) => ipcRenderer.sendSync('host:shell:openExternal', url),
  },

  quit:          ()   => ipcRenderer.invoke('host:quit'),
  setFullscreen: (on) => ipcRenderer.invoke(on ? 'host:fullscreen:on' : 'host:fullscreen:off'),

  // register a renderer callback for OS window focus changes (main pushes host:focus)
  onFocusChange: (cb) => ipcRenderer.on('host:focus', (_e, focused) => cb(focused)),

  debug: {
    writeRegionRoads:     (text)         => ipcRenderer.sendSync('host:debug:roads', text),
    writeRegionBuildings: (text)         => ipcRenderer.sendSync('host:debug:buildings', text),
    writeImage:           (name, base64) => ipcRenderer.sendSync('host:debug:image', name, base64),
  },
});
