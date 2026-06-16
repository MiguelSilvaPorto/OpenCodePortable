# Helper script para patchear stt.js com segurança e garantir gravação universal
$sttFile = Join-Path $env:USERPROFILE ".cache\opencode\packages\@renjfk\opencode-voice@latest\node_modules\@renjfk\opencode-voice\lib\stt.js"

if (Test-Path $sttFile) {
    # Restaurar arquivo original para evitar patches acumulados incorretos
    $backupFile = "$sttFile.bak"
    if (Test-Path $backupFile) {
        Copy-Item -Path $backupFile -Destination $sttFile -Force
    } else {
        Copy-Item -Path $sttFile -Destination $backupFile -Force
    }

    # Ler conteúdo em UTF8 e forçar o tratamento em aspas simples do PS
    $content = [System.IO.File]::ReadAllText($sttFile, [System.Text.Encoding]::UTF8)

    # 1. Ampliar filtro de detecção para incluir qualquer dispositivo ou falhar graciosamente
    $content = $content.Replace('l.toLowerCase().includes("micro")', 'l.toLowerCase().includes("micro") || l.toLowerCase().includes("audio") || l.toLowerCase().includes("usb") || l.toLowerCase().includes("input") || l.toLowerCase().includes("sound") || l.toLowerCase().includes("stereo") || l.toLowerCase().includes("rec") || l.toLowerCase().includes("mix")')

    # 2. Criar a variável de controle global 'isFallback' no stt.js
    $globalVars = 'let sttApiEndpoint = null;' + [char]13 + [char]10 + 'let sttApiModel = null;' + [char]13 + [char]10 + 'let sttApiKeyEnv = null;' + [char]13 + [char]10 + 'let isFallback = false;'
    $content = $content.Replace('let sttApiEndpoint = null;' + [char]13 + [char]10 + 'let sttApiModel = null;' + [char]13 + [char]10 + 'let sttApiKeyEnv = null;', $globalVars)

    # 3. Reescrever o método de seleção de dispositivos no Windows para ser totalmente portátil e tolerante a falhas
    $targetDeviceSelection = '  if (process.platform === "win32") {' + [char]13 + [char]10 +
'    let dev = kv.get("stt.mic", "");' + [char]13 + [char]10 +
'    if (!dev) {' + [char]13 + [char]10 +
'      const devs = listInputDevices();' + [char]13 + [char]10 +
'      if (devs.length > 0) {' + [char]13 + [char]10 +
'        dev = devs[0];' + [char]13 + [char]10 +
'      }' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'    if (dev) {' + [char]13 + [char]10 +
'      inputArgs = ["-t", "waveaudio", dev];' + [char]13 + [char]10 +
'    } else {' + [char]13 + [char]10 +
'      inputArgs = ["-t", "waveaudio", "default"];' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'  }'

    $replaceDeviceSelection = '  if (process.platform === "win32") {' + [char]13 + [char]10 +
'    let dev = kv.get("stt.mic", "");' + [char]13 + [char]10 +
'    if (!dev) {' + [char]13 + [char]10 +
'      const devs = listInputDevices();' + [char]13 + [char]10 +
'      if (devs.length > 0) {' + [char]13 + [char]10 +
'        dev = devs[0];' + [char]13 + [char]10 +
'      }' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'    if (isFallback) {' + [char]13 + [char]10 +
'      inputArgs = ["-d"];' + [char]13 + [char]10 +
'    } else if (dev) {' + [char]13 + [char]10 +
'      inputArgs = ["-t", "waveaudio", dev];' + [char]13 + [char]10 +
'    } else {' + [char]13 + [char]10 +
'      inputArgs = ["-d"];' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'  }'

    $content = $content.Replace($targetDeviceSelection, $replaceDeviceSelection)

    # 4. Modificar o manipulador de erro do spawn do SoX para realizar a tentativa de fallback silencioso
    $targetErrorHandler = '  soxProc.on("exit", (code) => {' + [char]13 + [char]10 +
'    soxProc = null;' + [char]13 + [char]10 +
'    clearInterval(whisperInterval);' + [char]13 + [char]10 +
'    if (recording && code !== 0 && code !== null && !processing) {' + [char]13 + [char]10 +
'      recording = false;' + [char]13 + [char]10 +
'      kv.set("stt.recording", false);' + [char]13 + [char]10 +
'      kv.set("stt.ghost_text", "");' + [char]13 + [char]10 +
'      const errLine = soxStderr.trim().split("\n").pop();' + [char]13 + [char]10 +
'      toast(`Recording error: ${errLine || `sox exited (code=${code})`}`, "error");' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'  });'

    $replaceErrorHandler = '  soxProc.on("exit", (code) => {' + [char]13 + [char]10 +
'    soxProc = null;' + [char]13 + [char]10 +
'    clearInterval(whisperInterval);' + [char]13 + [char]10 +
'    if (recording && code !== 0 && code !== null && !processing) {' + [char]13 + [char]10 +
'      const errLine = soxStderr.trim().split("\n").pop();' + [char]13 + [char]10 +
'      if (!isFallback && (errLine && (errLine.includes("no default audio") || errLine.includes("WaveAudio device") || errLine.includes("can") && errLine.includes("open")))) {' + [char]13 + [char]10 +
'        isFallback = true;' + [char]13 + [char]10 +
'        console.log("[stt] waveaudio failed, retrying recording with universal fallback -d...");' + [char]13 + [char]10 +
'        startRecording(kv, toast, client);' + [char]13 + [char]10 +
'      } else {' + [char]13 + [char]10 +
'        recording = false;' + [char]13 + [char]10 +
'        isFallback = false;' + [char]13 + [char]10 +
'        kv.set("stt.recording", false);' + [char]13 + [char]10 +
'        kv.set("stt.ghost_text", "");' + [char]13 + [char]10 +
'        toast(`Recording error: ${errLine || `sox exited (code=${code})`}`, "error");' + [char]13 + [char]10 +
'      }' + [char]13 + [char]10 +
'    } else {' + [char]13 + [char]10 +
'      isFallback = false;' + [char]13 + [char]10 +
'    }' + [char]13 + [char]10 +
'  });'

    $content = $content.Replace($targetErrorHandler, $replaceErrorHandler)

    [System.IO.File]::WriteAllText($sttFile, $content, [System.Text.Encoding]::UTF8)
}
