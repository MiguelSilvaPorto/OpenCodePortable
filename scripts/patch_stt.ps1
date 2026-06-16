# Helper script para patchear stt.js com segurança e evitar problemas de expansão no .bat
$sttFile = Join-Path $env:USERPROFILE ".cache\opencode\packages\@renjfk\opencode-voice@latest\node_modules\@renjfk\opencode-voice\lib\stt.js"

if (Test-Path $sttFile) {
    $content = Get-Content $sttFile -Raw -Encoding UTF8
    $changed = $false

    # 1. Patch de dispositivos extras
    if ($content -notmatch 'includes\("audio"\)') {
        $content = $content.Replace('l.toLowerCase().includes("micro")', 'l.toLowerCase().includes("micro") || l.toLowerCase().includes("audio") || l.toLowerCase().includes("usb") || l.toLowerCase().includes("input")')
        $changed = $true
    }

    # 2. Patch de fallback do Sox
    if ($content -notmatch 'recording failed, retrying with default device') {
        $target = '  soxProc = spawn(' + [char]10 + '    "sox",' + [char]10 + '    ["--buffer", "2048", ...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE],'
        $replace = '  // Fallback se waveaudio falhar' + [char]13 + [char]10 + '  let isFallback = false;' + [char]13 + [char]10 + '  if (process.platform === "win32" && inputArgs[1] === "waveaudio" && inputArgs[2] === "default") {' + [char]13 + [char]10 + '    // Se der erro de default audio device, tentamos rodar o SoX sem waveaudio (so com -d)' + [char]13 + [char]10 + '  }' + [char]13 + [char]10 + '  soxProc = spawn(' + [char]13 + [char]10 + '    "sox",' + [char]13 + [char]10 + '    ["--buffer", "2048", ...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE],'
        $content = $content.Replace($target, $replace)
        $content = $content.Replace('toast(`Recording error: ${errLine || `sox exited (code=${code})`}`, "error");', 'if (!isFallback && errLine && errLine.includes("no default audio device")) {' + [char]13 + [char]10 + '        isFallback = true;' + [char]13 + [char]10 + '        console.log("[stt] waveaudio default failed, retrying with default device -d...");' + [char]13 + [char]10 + '        inputArgs = ["-d"];' + [char]13 + [char]10 + '        startRecording(kv, toast, client);' + [char]13 + [char]10 + '      } else {' + [char]13 + [char]10 + '        toast(`Recording error: ${errLine || `sox exited (code=${code})`}`, "error");' + [char]13 + [char]10 + '      }')
        $changed = $true
    }

    if ($changed) {
        Set-Content -Path $sttFile -Value $content -NoNewline -Encoding UTF8
    }
}
