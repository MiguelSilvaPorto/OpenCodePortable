const fs = require('fs');
const path = require('path');
const os = require('os');

const cacheDir = path.join(os.homedir(), '.cache', 'opencode', 'packages', '@renjfk', 'opencode-voice@latest');
const sttFile = path.join(cacheDir, 'node_modules', '@renjfk', 'opencode-voice', 'lib', 'stt.js');
const backupFile = sttFile + '.bak';

if (!fs.existsSync(sttFile)) {
  console.log('[PATCH] stt.js not found, skipping patching.');
  process.exit(0);
}

// Ensure clean restore from backup to avoid cumulative patching issues
if (fs.existsSync(backupFile)) {
  fs.copyFileSync(backupFile, sttFile);
} else {
  fs.copyFileSync(sttFile, backupFile);
}

let content = fs.readFileSync(sttFile, 'utf8');

// Normalize line endings to LF to ensure match patterns succeed reliably
content = content.replace(/\r\n/g, '\n');

// 0. Import https module at the top
content = 'import https from "node:https";\n' + content;

// 1. Update WAV_FILE path
content = content.replace(
  'const WAV_FILE = "/tmp/opencode-stt.wav";',
  'const WAV_FILE = path.join(os.tmpdir(), "opencode-stt.wav");'
);

// 2. Define global variables and writeSilentWav helper + downloadModel helper
const helperCode = `
let isSimulated = false;

function writeSilentWav(filePath) {
  try {
    const sampleRate = 16000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const dataSize = sampleRate * numChannels * (bitsPerSample / 8);
    const buffer = Buffer.alloc(44 + dataSize);
    
    buffer.write("RIFF", 0);
    buffer.writeUInt32LE(36 + dataSize, 4);
    buffer.write("WAVE", 8);
    
    buffer.write("fmt ", 12);
    buffer.writeUInt32LE(16, 16);
    buffer.writeUInt16LE(1, 20);
    buffer.writeUInt16LE(numChannels, 22);
    buffer.writeUInt32LE(sampleRate, 24);
    buffer.writeUInt32LE(sampleRate * numChannels * (bitsPerSample / 8), 28);
    buffer.writeUInt16LE(numChannels * (bitsPerSample / 8), 32);
    buffer.writeUInt16LE(bitsPerSample, 34);
    
    buffer.write("data", 36);
    buffer.writeUInt32LE(dataSize, 40);
    
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, buffer);
  } catch (err) {
    console.error("Failed to write silent WAV:", err);
  }
}

function downloadModel(modelFile, destPath, toast) {
  const url = \`https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\${modelFile}\`;
  toast(\`Downloading Whisper model (\${modelFile})... please wait\`, "info");
  
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  const file = fs.createWriteStream(destPath);
  
  return new Promise((resolve, reject) => {
    function getUrl(targetUrl) {
      https.get(targetUrl, { headers: { "User-Agent": "Mozilla/5.0" } }, (response) => {
        if (response.statusCode === 302 || response.statusCode === 301) {
          getUrl(response.headers.location);
        } else if (response.statusCode !== 200) {
          fs.unlink(destPath, () => {});
          reject(new Error(\`HTTP status \${response.statusCode}\`));
        } else {
          response.pipe(file);
          file.on('finish', () => {
            file.close();
            resolve();
          });
        }
      }).on('error', (err) => {
        fs.unlink(destPath, () => {});
        reject(err);
      });
    }
    getUrl(url);
  });
}
`;

content = content.replace('let soxProc = null;', 'let soxProc = null;\n' + helperCode);

// Change default model to "base"
content = content.replace(
  'const DEFAULT_MODEL = "large-v3-turbo-q5_0";',
  'const DEFAULT_MODEL = "base";'
);

// Add rule to preserve language to system prompt
content = content.replace(
  '- Keep the user\'s intent and meaning intact',
  '- Keep the user\'s intent and meaning intact\n- ALWAYS respond/normalize in the language the user dictated (e.g. if dictated in Portuguese, output in Portuguese. Do NOT translate to English).'
);

// 3. Replace startRecording
const originalStartRecording = `function startRecording(kv, toast) {
  if (soxProc) return;

  forceKillSox();
  try {
    fs.unlinkSync(WAV_FILE);
  } catch {}

  soxStderr = "";
  const mic = kv.get("stt.mic", "") || null;
  const inputArgs = mic ? ["-t", "coreaudio", mic] : ["-d"];

  soxProc = spawn(
    "sox",
    [...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE, "silence", "1", "0.1", "1%"],
    {
      stdio: ["ignore", "ignore", "pipe"],
      detached: false,
    },
  );

  soxProc.stderr.on("data", (chunk) => {
    soxStderr += chunk.toString();
  });

  soxProc.on("error", (err) => {
    soxProc = null;
    if (recording) {
      recording = false;
      toast(\`Recording failed: \${err.message}\`, "error");
    }
  });

  soxProc.on("exit", (code) => {
    soxProc = null;
    if (recording && code !== 0 && code !== null && !processing) {
      recording = false;
      const errLine = soxStderr.trim().split("\\n").pop();
      toast(\`Recording error: \${errLine || \`sox exited (code=\${code})\`}\`, "error");
    }
  });

  recording = true;
}`;

const patchedStartRecording = `function startRecording(kv, toast) {
  if (soxProc) return;

  forceKillSox();
  try {
    if (fs.existsSync(WAV_FILE)) fs.unlinkSync(WAV_FILE);
  } catch {}

  soxStderr = "";

  if (isSimulated) {
    writeSilentWav(WAV_FILE);
    recording = true;
    kv.set("stt.recording", true);
    return;
  }

  const mic = kv.get("stt.mic", "") || null;
  let inputArgs = [];
  if (process.platform === "win32") {
    inputArgs = mic ? ["-t", "waveaudio", mic] : ["-t", "waveaudio", "default"];
  } else if (process.platform === "darwin") {
    inputArgs = mic ? ["-t", "coreaudio", mic] : ["-d"];
  } else {
    inputArgs = mic ? ["-t", "alsa", mic] : ["-d"];
  }

  soxProc = spawn(
    "sox",
    [...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE, "silence", "1", "0.1", "1%"],
    {
      stdio: ["ignore", "ignore", "pipe"],
      detached: false,
    },
  );

  soxProc.stderr.on("data", (chunk) => {
    soxStderr += chunk.toString();
  });

  soxProc.on("error", (err) => {
    soxProc = null;
    if (recording) {
      isSimulated = true;
      writeSilentWav(WAV_FILE);
      toast("Audio recording failed. Simulating silent recording...", "warning");
      kv.set("stt.recording", true);
    }
  });

  soxProc.on("exit", (code) => {
    soxProc = null;
    if (recording && code !== 0 && code !== null && !processing) {
      const errLine = soxStderr.trim().split("\\n").pop();
      const lowerErr = (errLine || "").toLowerCase();
      if (lowerErr.includes("no default audio") || lowerErr.includes("waveaudio device") || lowerErr.includes("can't open") || lowerErr.includes("fail")) {
        isSimulated = true;
        writeSilentWav(WAV_FILE);
        toast("No audio device detected. Simulating silent recording...", "warning");
        kv.set("stt.recording", true);
      } else {
        recording = false;
        kv.set("stt.recording", false);
        kv.set("stt.ghost_text", "");
        toast(\`Recording error: \${errLine || \`sox exited (code=\${code})\`}\`, "error");
      }
    }
  });

  recording = true;
}`;

content = content.replace(originalStartRecording, patchedStartRecording);

// 4. Replace stopRecording
const originalStopRecording = `function stopRecording() {
  if (soxProc) soxProc.kill("SIGINT");
}`;

const patchedStopRecording = `function stopRecording() {
  if (isSimulated) {
    return;
  }
  if (soxProc) soxProc.kill("SIGINT");
}`;

content = content.replace(originalStopRecording, patchedStopRecording);

// 5. Replace transcribe function to support -l <lang> for Portuguese / auto detection
const originalTranscribe = `function transcribe(kv) {
  const mp = getModelPath(kv);
  if (!fs.existsSync(mp)) {
    return Promise.resolve({
      error: \`Model not found: \${getModelName(kv)}. Download from huggingface.co/ggerganov/whisper.cpp\`,
    });
  }
  if (!fs.existsSync(WAV_FILE)) {
    return Promise.resolve({ error: "No recording file - sox may have failed to capture audio" });
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    return Promise.resolve({ error: "Recording is empty - no audio captured" });
  }

  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    const proc = spawn("whisper-cli", ["-m", mp, "-f", WAV_FILE, "-np", "-nt"], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    const timer = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve({ error: "Transcription timed out (60s)" });
    }, 60000);

    proc.on("error", (err) => {
      clearTimeout(timer);
      resolve({ error: \`Transcription failed: \${err.message}\` });
    });

    proc.on("exit", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        resolve({ error: stderr.trim().split("\\n").pop() || \`whisper-cli exited (code=\${code})\` });
        return;
      }
      resolve({
        text: stdout
          .replace(/\\[.*?\\]/g, "")
          .replace(/\\(.*?\\)/g, "")
          .replace(/\\s+/g, " ")
          .trim(),
      });
    });
  });
}`;

const patchedTranscribe = `async function transcribe(kv, toast) {
  const mp = getModelPath(kv);
  if (!fs.existsSync(mp)) {
    const modelName = getModelName(kv);
    const modelFile = MODELS[modelName].file;
    try {
      await downloadModel(modelFile, mp, toast);
      toast(\`Whisper model \${modelName} downloaded successfully!\`, "success");
    } catch (err) {
      return { error: \`Whisper model \${modelName} not found, and auto-download failed: \${err.message}\` };
    }
  }
  if (!fs.existsSync(WAV_FILE)) {
    return { error: "No recording file - sox may have failed to capture audio" };
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    return { error: "Recording is empty - no audio captured" };
  }

  const lang = kv.get("stt.language", "pt");

  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    const proc = spawn("whisper-cli", ["-m", mp, "-f", WAV_FILE, "-np", "-nt", "-l", lang], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    const timer = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve({ error: "Transcription timed out (60s)" });
    }, 60000);

    proc.on("error", (err) => {
      clearTimeout(timer);
      resolve({ error: \`Transcription failed: \${err.message}\` });
    });

    proc.on("exit", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        resolve({ error: stderr.trim().split("\\n").pop() || \`whisper-cli exited (code=\${code})\` });
        return;
      }
      resolve({
        text: stdout
          .replace(/\\[.*?\\\]/g, "")
          .replace(/\\(.*?\\)/g, "")
          .replace(/\\s+/g, " ")
          .trim(),
      });
    });
  });
}`;

content = content.replace(originalTranscribe, patchedTranscribe);

// 6. Replace transcribeApi function to support API language specification
const originalTranscribeApi = `async function transcribeApi(kv) {
  if (!sttApiEndpoint || !sttApiModel) {
    return { error: "STT API not configured" };
  }
  const model = kv.get("stt.api.model") || sttApiModel;

  if (!fs.existsSync(WAV_FILE)) {
    return { error: "No recording file - sox may have failed to capture audio" };
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    return { error: "Recording is empty - no audio captured" };
  }

  try {
    const audioBuffer = await fs.promises.readFile(WAV_FILE);
    const blob = new Blob([audioBuffer], { type: "audio/wav" });
    const form = new FormData();
    form.append("file", blob, "audio.wav");
    form.append("model", model);
    form.append("response_format", "json");

    const url = sttApiEndpoint.endsWith("/")
      ? \`\${sttApiEndpoint}audio/transcriptions\`
      : \`\${sttApiEndpoint}/audio/transcriptions\`;

    const headers = {};
    if (sttApiKeyEnv) {
      const apiKey = process.env[sttApiKeyEnv];
      if (apiKey) headers["Authorization"] = "Bearer " + apiKey;
    }

    const resp = await fetch(url, {
      method: "POST",
      headers,
      body: form,
      signal: AbortSignal.timeout(60000),
    });

    if (!resp.ok) {
      const body = await resp.text();
      let msg = \`STT API error \${resp.status}\`;
      try {
        const err = JSON.parse(body);
        msg = err?.error?.message || msg;
      } catch {}
      return { error: msg };
    }

    const data = await resp.json();
    return { text: data.text?.trim() || "" };
  } catch (err) {
    if (err.name === "TimeoutError" || err.name === "AbortError") {
      return { error: "STT API request timed out (60s)" };
    }
    return { error: \`STT API request failed: \${err.message}\` };
  }
}`;

const patchedTranscribeApi = `async function transcribeApi(kv) {
  if (!sttApiEndpoint || !sttApiModel) {
    return { error: "STT API not configured" };
  }
  const model = kv.get("stt.api.model") || sttApiModel;

  if (!fs.existsSync(WAV_FILE)) {
    return { error: "No recording file - sox may have failed to capture audio" };
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    return { error: "Recording is empty - no audio captured" };
  }

  try {
    const audioBuffer = await fs.promises.readFile(WAV_FILE);
    const blob = new Blob([audioBuffer], { type: "audio/wav" });
    const form = new FormData();
    form.append("file", blob, "audio.wav");
    form.append("model", model);
    form.append("response_format", "json");
    
    const lang = kv.get("stt.language", "pt");
    form.append("language", lang);

    const url = sttApiEndpoint.endsWith("/")
      ? \`\${sttApiEndpoint}audio/transcriptions\`
      : \`\${sttApiEndpoint}/audio/transcriptions\`;

    const headers = {};
    if (sttApiKeyEnv) {
      const apiKey = process.env[sttApiKeyEnv];
      if (apiKey) headers["Authorization"] = "Bearer " + apiKey;
    }

    const resp = await fetch(url, {
      method: "POST",
      headers,
      body: form,
      signal: AbortSignal.timeout(60000),
    });

    if (!resp.ok) {
      const body = await resp.text();
      let msg = \`STT API error \${resp.status}\`;
      try {
        const err = JSON.parse(body);
        msg = err?.error?.message || msg;
      } catch {}
      return { error: msg };
    }

    const data = await resp.json();
    return { text: data.text?.trim() || "" };
  } catch (err) {
    if (err.name === "TimeoutError" || err.name === "AbortError") {
      return { error: "STT API request timed out (60s)" };
    }
    return { error: \`STT API request failed: \${err.message}\` };
  }
}`;

content = content.replace(originalTranscribeApi, patchedTranscribeApi);

// 7. Replace doTranscribePipeline
const originalDoTranscribePipeline = `async function doTranscribePipeline(kv, complete, client, toast, systemPrompt, submit = false) {
  processing = true;
  try {
    stopRecording();
    await waitForSoxExit();

    toast("Transcribing...");
    const result = sttApiEndpoint ? await transcribeApi(kv) : await transcribe(kv);

    if (result.error) {
      toast(result.error, "error");
      return;
    }
    if (!result.text) {
      toast("No speech detected", "warning");
      return;
    }

    toast("Normalizing...");
    const sessionTitle = await getActiveSessionTitle(client);
    const llmResult = await normalizeTranscription(
      complete,
      result.text,
      sessionTitle,
      systemPrompt,
    );

    if (!llmResult.text) {
      toast(\`Normalization failed, using raw input: \${llmResult.error}\`, "warning");
      await appendTranscription(client, result.text, submit);
      return;
    }

    await appendTranscription(client, llmResult.text, submit);
    toast(submit ? "Transcription submitted" : "Transcription added to prompt", "success");
  } catch (err) {
    toast(\`STT error: \${err.message}\`, "error");
  } finally {
    processing = false;
    recording = false;
  }
}`;

const patchedDoTranscribePipeline = `async function doTranscribePipeline(kv, complete, client, toast, systemPrompt, submit = false) {
  processing = true;
  try {
    stopRecording();
    await waitForSoxExit();

    toast("Transcribing...");
    
    if (isSimulated) {
      writeSilentWav(WAV_FILE);
    }

    const result = sttApiEndpoint ? await transcribeApi(kv) : await transcribe(kv, toast);

    if (result.error) {
      if (isSimulated) {
        toast("Simulated recording finished (no audio device)", "warning");
        return;
      }
      toast(result.error, "error");
      return;
    }
    if (!result.text) {
      if (isSimulated) {
        toast("Simulated recording: No speech detected", "warning");
      } else {
        toast("No speech detected", "warning");
      }
      return;
    }

    toast("Normalizing...");
    const sessionTitle = await getActiveSessionTitle(client);
    const llmResult = await normalizeTranscription(
      complete,
      result.text,
      sessionTitle,
      systemPrompt,
    );

    if (!llmResult.text) {
      toast(\`Normalization failed, using raw input: \${llmResult.error}\`, "warning");
      await appendTranscription(client, result.text, submit);
      return;
    }

    await appendTranscription(client, llmResult.text, submit);
    toast(submit ? "Transcription submitted" : "Transcription added to prompt", "success");
  } catch (err) {
    toast(\`STT error: \${err.message}\`, "error");
  } finally {
    processing = false;
    recording = false;
    isSimulated = false;
  }
}`;

content = content.replace(originalDoTranscribePipeline, patchedDoTranscribePipeline);

// Write patched content
fs.writeFileSync(sttFile, content, 'utf8');
console.log('[PATCH] stt.js successfully patched with language configuration and simulation.');
