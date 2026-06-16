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

// 1. Update WAV_FILE path
content = content.replace(
  'const WAV_FILE = "/tmp/opencode-stt.wav";',
  'const WAV_FILE = path.join(os.tmpdir(), "opencode-stt.wav");'
);

// 2. Define global variables and writeSilentWav helper
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
`;

content = content.replace('let soxProc = null;', 'let soxProc = null;\n' + helperCode);

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

// 5. Replace doTranscribePipeline
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

    const result = sttApiEndpoint ? await transcribeApi(kv) : await transcribe(kv);

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
console.log('[PATCH] stt.js successfully patched with simulated recording support.');
