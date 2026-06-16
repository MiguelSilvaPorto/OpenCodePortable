const fs = require('fs');
const path = require('path');
const os = require('os');

const cacheDir = path.join(os.homedir(), '.cache', 'opencode', 'packages', '@renjfk', 'opencode-voice@latest');
const indexFile = path.join(cacheDir, 'node_modules', '@renjfk', 'opencode-voice', 'index.js');
const sttFile = path.join(cacheDir, 'node_modules', '@renjfk', 'opencode-voice', 'lib', 'stt.js');
const llmClientFile = path.join(cacheDir, 'node_modules', '@renjfk', 'opencode-voice', 'lib', 'llm-client.js');

// Helper to safely restore from backup and read/write patched contents
function patchFile(filePath, patchFn) {
  if (!fs.existsSync(filePath)) {
    console.log(`[PATCH] File not found: ${filePath}`);
    return;
  }
  const backupFile = filePath + '.bak';
  if (fs.existsSync(backupFile)) {
    fs.copyFileSync(backupFile, filePath);
  } else {
    fs.copyFileSync(filePath, backupFile);
  }
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(/\r\n/g, '\n');
  content = patchFn(content);
  fs.writeFileSync(filePath, content, 'utf8');
}

// 1. Patch index.js to pass kv to createClient
patchFile(indexFile, (content) => {
  return content.replace(
    'const { complete } = createClient(options);',
    'const { complete } = createClient(options, kv);'
  );
});
console.log('[PATCH] index.js successfully patched.');

// 2. Patch llm-client.js to support dynamic configurations from kv and prioritize explicit apiKey
patchFile(llmClientFile, (content) => {
  // Update createClient declaration
  content = content.replace(
    'export function createClient(pluginOptions) {',
    'export function createClient(pluginOptions, kv) {'
  );

  // Update getConfig to resolve options from kv dynamically
  const originalGetConfig = `  function getConfig() {
    return {
      endpoint: pluginOptions?.endpoint,
      model: pluginOptions?.model,
      apiKeyEnv: pluginOptions?.apiKeyEnv,
      maxTokens: pluginOptions?.maxTokens ?? DEFAULTS.maxTokens,
      reasoningEffort: pluginOptions?.reasoningEffort ?? DEFAULTS.reasoningEffort,
      chatTemplateKwargs: normalizeChatTemplateKwargs(
        pluginOptions?.chatTemplateKwargs ?? DEFAULTS.chatTemplateKwargs,
      ),
      retries: normalizeRetries(pluginOptions?.retries ?? DEFAULTS.retries),
    };
  }`;

  const patchedGetConfig = `  function getConfig() {
    return {
      endpoint: kv?.get("stt.endpoint") || pluginOptions?.endpoint,
      model: kv?.get("stt.llmModel") || pluginOptions?.model,
      apiKeyEnv: kv?.get("stt.sttApiKeyEnv") !== undefined ? kv.get("stt.sttApiKeyEnv") : pluginOptions?.apiKeyEnv,
      apiKey: kv?.get("stt.apiKey") || pluginOptions?.apiKey,
      maxTokens: pluginOptions?.maxTokens ?? DEFAULTS.maxTokens,
      reasoningEffort: pluginOptions?.reasoningEffort ?? DEFAULTS.reasoningEffort,
      chatTemplateKwargs: normalizeChatTemplateKwargs(
        pluginOptions?.chatTemplateKwargs ?? DEFAULTS.chatTemplateKwargs,
      ),
      retries: normalizeRetries(pluginOptions?.retries ?? DEFAULTS.retries),
    };
  }`;

  content = content.replace(originalGetConfig, patchedGetConfig);

  // Prioritize explicit apiKey over environment variable apiKeyEnv
  const originalKeyLine = 'const apiKey = cfg.apiKeyEnv ? process.env[cfg.apiKeyEnv] : null;';
  const patchedKeyLine = 'const apiKey = cfg.apiKey || (cfg.apiKeyEnv ? process.env[cfg.apiKeyEnv] : null) || null;';
  content = content.replace(originalKeyLine, patchedKeyLine);

  return content;
});
console.log('[PATCH] llm-client.js successfully patched.');

// 3. Patch stt.js to support dynamic STT configs, /voice menu command, and prioritize explicit apiKey
patchFile(sttFile, (content) => {
  // Import https at the top
  content = 'import https from "node:https";\n' + content;

  // Update WAV_FILE path
  content = content.replace(
    'const WAV_FILE = "/tmp/opencode-stt.wav";',
    'const WAV_FILE = path.join(os.tmpdir(), "opencode-stt.wav");'
  );

  // Define global variables, writeSilentWav, downloadModel, getClipboardText helpers and sttApiKeyVal
  const helperCode = `
let isSimulated = false;
let sttApiKeyVal = null;

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

function getClipboardText() {
  try {
    let text = "";
    if (process.platform === "win32") {
      text = execSync("powershell -NoProfile -Command Get-Clipboard", { encoding: "utf-8", timeout: 2000 });
    } else if (process.platform === "darwin") {
      text = execSync("pbpaste", { encoding: "utf-8", timeout: 2000 });
    } else {
      text = execSync("xclip -selection clipboard -o", { encoding: "utf-8", timeout: 2000 });
    }
    return (text || "").trim().replace(/[^a-zA-Z0-9_-]/g, "");
  } catch {
    return "";
  }
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

  // Replace startRecording
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

  // Replace stopRecording
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

  // Replace transcribe function to support -l <lang> for Portuguese / auto detection
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

  // Replace transcribeApi function to support API language specification and dynamic configs from KV, prioritizing explicit apiKey
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
  const apiEndpoint = kv.get("stt.sttEndpoint") !== undefined ? kv.get("stt.sttEndpoint") : sttApiEndpoint;
  const apiModel = kv.get("stt.sttModel") || sttApiModel;
  const apiKeyEnvName = kv.get("stt.sttApiKeyEnv") !== undefined ? kv.get("stt.sttApiKeyEnv") : sttApiKeyEnv;

  if (!apiEndpoint || !apiModel) {
    return { error: "STT API not configured" };
  }
  const model = kv.get("stt.api.model") || apiModel;

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

    const url = apiEndpoint.endsWith("/")
      ? \`\${apiEndpoint}audio/transcriptions\`
      : \`\${apiEndpoint}/audio/transcriptions\`;

    const headers = {};
    const apiKey = sttApiKeyVal || (apiKeyEnvName ? process.env[apiKeyEnvName] : null) || null;
    if (apiKey) headers["Authorization"] = "Bearer " + apiKey;

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

  // Set sttApiKeyVal when registerSTT is run and update dynamic sttApiEndpoint resolve in pipeline
  const originalRegisterBlock = `  if (opts?.sttEndpoint) {
    sttApiEndpoint = opts.sttEndpoint;
    sttApiModel = opts.sttModel || "whisper-large-v3-turbo";
    sttApiKeyEnv = opts.sttApiKeyEnv || null;
  }`;

  const patchedRegisterBlock = `  if (opts?.sttEndpoint) {
    sttApiEndpoint = opts.sttEndpoint;
    sttApiModel = opts.sttModel || "whisper-large-v3-turbo";
    sttApiKeyEnv = opts.sttApiKeyEnv || null;
  }
  sttApiKeyVal = opts?.apiKey || null;`;

  content = content.replace(originalRegisterBlock, patchedRegisterBlock);

  // Replace doTranscribePipeline to use dynamic sttApiEndpoint
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

    const currentEndpoint = kv.get("stt.sttEndpoint") !== undefined ? kv.get("stt.sttEndpoint") : sttApiEndpoint;
    const result = currentEndpoint ? await transcribeApi(kv) : await transcribe(kv, toast);

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

  // Register the new /voice setup command
  const originalRegisterSTTFnStart = `export function registerSTT(api, kv, complete, prompts, opts) {
  const client = api.client;
  const systemPrompt = prompts?.stt || STT_SYSTEM_PROMPT;
  function toast(message, variant = "info") {
    api.ui.toast({ message, variant, duration: 3000 });
  }

  if (opts?.sttEndpoint) {
    sttApiEndpoint = opts.sttEndpoint;
    sttApiModel = opts.sttModel || "whisper-large-v3-turbo";
    sttApiKeyEnv = opts.sttApiKeyEnv || null;
  }
  sttApiKeyVal = opts?.apiKey || null;

  return [`;

  const voiceCommandCode = `    {
      title: "Voice: Setup (Configurar Voz)",
      value: "voice.setup",
      description: "Configure language, provider (Groq/Ollama), and audio settings",
      slash: { name: "voice" },
      onSelect() {
        const showMainMenu = () => {
          const provider = kv.get("stt.provider") || (sttApiEndpoint ? "groq" : "ollama");
          const language = kv.get("stt.language", "pt");
          const mic = kv.get("stt.mic", "") || "System default";
          
          api.ui.dialog.replace(() =>
            api.ui.DialogSelect({
              title: "Voice Setup (Configuração de Voz)",
              options: [
                {
                  title: \`1. Idioma (Language): [\${language}]\`,
                  value: "voice.lang",
                  onSelect() {
                    api.ui.dialog.replace(() =>
                      api.ui.DialogSelect({
                        title: "Select Language / Selecionar Idioma",
                        options: [
                          { title: "Português (pt)", value: "pt", onSelect() { kv.set("stt.language", "pt"); toast("Idioma: pt"); showMainMenu(); } },
                          { title: "English (en)", value: "en", onSelect() { kv.set("stt.language", "en"); toast("Language: en"); showMainMenu(); } },
                          { title: "Español (es)", value: "es", onSelect() { kv.set("stt.language", "es"); toast("Idioma: es"); showMainMenu(); } },
                          { title: "Auto-detect (auto)", value: "auto", onSelect() { kv.set("stt.language", "auto"); toast("Language: auto"); showMainMenu(); } }
                        ]
                      })
                    );
                  }
                },
                {
                  title: \`2. Provedor (Provider): [\${provider.toUpperCase()}]\`,
                  value: "voice.provider",
                  onSelect() {
                    api.ui.dialog.replace(() =>
                      api.ui.DialogSelect({
                        title: "Select Provider / Selecionar Provedor",
                        options: [
                          {
                            title: "Groq Cloud (Recomendado - Rápido & Nuvem)",
                            value: "groq",
                            onSelect() {
                              kv.set("stt.provider", "groq");
                              kv.set("stt.sttEndpoint", "https://api.groq.com/openai/v1");
                              kv.set("stt.sttModel", "whisper-large-v3-turbo");
                              kv.set("stt.endpoint", "https://api.groq.com/openai/v1");
                              kv.set("stt.llmModel", "llama3-8b-8192");
                              kv.set("stt.sttApiKeyEnv", "GROQ_API_KEY");
                              const envKey = process.env.GROQ_API_KEY || "";
                              if (envKey) {
                                kv.set("stt.apiKey", envKey);
                                sttApiKeyVal = envKey;
                              }
                              toast("Provedor alterado para Groq Cloud");
                              showMainMenu();
                            }
                          },
                          {
                            title: "Ollama Local (Offline & Processamento Local)",
                            value: "ollama",
                            onSelect() {
                              kv.set("stt.provider", "ollama");
                              kv.set("stt.sttEndpoint", "");
                              kv.set("stt.sttModel", "");
                              kv.set("stt.endpoint", "http://localhost:11434/v1");
                              kv.set("stt.llmModel", "llama3.2");
                              kv.set("stt.sttApiKeyEnv", "");
                              toast("Provedor alterado para Ollama Local");
                              showMainMenu();
                            }
                          }
                        ]
                      })
                    );
                  }
                },
                {
                  title: "3. Colar Groq API Key da Área de Transferência (Clipboard)",
                  value: "voice.paste_key",
                  onSelect() {
                    const clipboardKey = getClipboardText();
                    if (clipboardKey && clipboardKey.startsWith("gsk_")) {
                      kv.set("stt.apiKey", clipboardKey);
                      sttApiKeyVal = clipboardKey; // Also update active key variable immediately
                      toast("Chave de API do Groq colada com sucesso!", "success");
                    } else if (clipboardKey) {
                      toast("Erro: Conteúdo da área de transferência não começa com 'gsk_'", "error");
                    } else {
                      toast("Área de transferência vazia", "warning");
                    }
                    showMainMenu();
                  }
                },
                {
                  title: "4. Selecionar Modelo LLM (Groq/Ollama)",
                  value: "voice.llm_model",
                  onSelect() {
                    if (provider === "groq") {
                      api.ui.dialog.replace(() =>
                        api.ui.DialogSelect({
                          title: "Select Groq LLM Model",
                          options: [
                            { title: "llama3-8b-8192 (Default)", value: "llama3-8b-8192", onSelect() { kv.set("stt.llmModel", "llama3-8b-8192"); toast("Modelo: llama3-8b-8192"); showMainMenu(); } },
                            { title: "llama-3.3-70b-versatile", value: "llama-3.3-70b-versatile", onSelect() { kv.set("stt.llmModel", "llama-3.3-70b-versatile"); toast("Modelo: llama-3.3-70b-versatile"); showMainMenu(); } },
                            { title: "mixtral-8x7b-32768", value: "mixtral-8x7b-32768", onSelect() { kv.set("stt.llmModel", "mixtral-8x7b-32768"); toast("Modelo: mixtral-8x7b-32768"); showMainMenu(); } }
                          ]
                        })
                      );
                    } else {
                      api.ui.dialog.replace(() =>
                        api.ui.DialogSelect({
                          title: "Select Ollama LLM Model",
                          options: [
                            { title: "llama3.2 (Default)", value: "llama3.2", onSelect() { kv.set("stt.llmModel", "llama3.2"); toast("Modelo: llama3.2"); showMainMenu(); } },
                            { title: "mistral", value: "mistral", onSelect() { kv.set("stt.llmModel", "mistral"); toast("Modelo: mistral"); showMainMenu(); } },
                            { title: "qwen2.5-coder", value: "qwen2.5-coder", onSelect() { kv.set("stt.llmModel", "qwen2.5-coder"); toast("Modelo: qwen2.5-coder"); showMainMenu(); } }
                          ]
                        })
                      );
                    }
                  }
                },
                {
                  title: "5. Selecionar Modelo Whisper (Local)",
                  value: "voice.whisper_model",
                  onSelect() {
                    const currentModel = getModelName(kv);
                    api.ui.dialog.replace(() =>
                      api.ui.DialogSelect({
                        title: "Select Whisper Model",
                        options: Object.entries(MODELS).map(([key, v]) => ({
                          title: v.label,
                          value: key,
                          onSelect() {
                            kv.set("stt.model", key);
                            toast(\`Whisper model: \${v.label}\`);
                            showMainMenu();
                          }
                        }))
                      })
                    );
                  }
                },
                {
                  title: \`6. Microfone (Mic): [\${mic}]\`,
                  value: "voice.mic",
                  onSelect() {
                    const currentMic = kv.get("stt.mic", "");
                    const devices = listInputDevices();
                    api.ui.dialog.replace(() =>
                      api.ui.DialogSelect({
                        title: "Select Microphone",
                        options: [
                          {
                            title: "System default",
                            value: "",
                            onSelect() {
                              kv.set("stt.mic", "");
                              toast("Mic: System default");
                              showMainMenu();
                            }
                          },
                          ...devices.map((name) => ({
                            title: name,
                            value: name,
                            onSelect() {
                              kv.set("stt.mic", name);
                              toast(\`Mic: \${name}\`);
                              showMainMenu();
                            }
                          }))
                        ]
                      })
                    );
                  }
                },
                {
                  title: "Sair (Fechar)",
                  value: "voice.exit",
                  onSelect() {
                    api.ui.dialog.clear();
                  }
                }
              ]
            })
          );
        };
        showMainMenu();
      }
    },`;

  content = content.replace(originalRegisterSTTFnStart, originalRegisterSTTFnStart + '\n' + voiceCommandCode);

  return content;
});

console.log('[PATCH] stt.js successfully patched with simulated recording, language config, clipboard integration, and /voice menu.');
